#include "linux_native_emacs_bridge.h"

#include <dirent.h>
#include <fcntl.h>
#include <limits.h>
#include <pty.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

#include <algorithm>
#include <cstring>
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>

struct WorkspaceEntry {
    std::string name;
    std::string path;
    bool is_directory;
    int64_t size_bytes;
};

static std::vector<WorkspaceEntry> ListDirectory(const std::string& path) {
    std::vector<WorkspaceEntry> entries;
    DIR* dir = opendir(path.c_str());
    if (!dir) return entries;
    
    struct dirent* entry;
    while ((entry = readdir(dir)) != nullptr) {
        std::string name = entry->d_name;
        if (name == "." || name == "..") continue;
        
        std::string full_path = path + "/" + name;
        struct stat st;
        if (stat(full_path.c_str(), &st) == 0) {
            bool is_directory = S_ISDIR(st.st_mode);
            int64_t size = is_directory ? 0 : static_cast<int64_t>(st.st_size);
            entries.push_back({name, full_path, is_directory, size});
        }
    }
    closedir(dir);
    std::sort(entries.begin(), entries.end(), [](const WorkspaceEntry& a, const WorkspaceEntry& b) {
        return a.name < b.name;
    });
    return entries;
}

static FlValue* WorkspaceEntryToFlValue(const WorkspaceEntry& entry) {
    FlValue* map = fl_value_new_map();
    fl_value_set_string_take(map, "name", fl_value_new_string(entry.name.c_str()));
    fl_value_set_string_take(map, "path", fl_value_new_string(entry.path.c_str()));
    fl_value_set_string_take(map, "isDirectory", fl_value_new_bool(entry.is_directory));
    fl_value_set_string_take(map, "sizeBytes", fl_value_new_int(entry.size_bytes));
    return map;
}

static std::string PathFromUri(const std::string& uri_str) {
    if (uri_str.rfind("file://", 0) == 0) {
        std::string path = uri_str.substr(7);
        std::string decoded;
        decoded.reserve(path.size());
        for (size_t i = 0; i < path.size(); ++i) {
            if (path[i] == '%' && i + 2 < path.size()) {
                char hex[3] = { path[i+1], path[i+2], '\0' };
                decoded += static_cast<char>(std::strtol(hex, nullptr, 16));
                i += 2;
            } else {
                decoded += path[i];
            }
        }
        return decoded;
    }
    return uri_str;
}

static std::string GetBaseName(const std::string& path) {
    size_t last_slash = path.find_last_of('/');
    if (last_slash == std::string::npos) {
        return path;
    }
    return path.substr(last_slash + 1);
}

static bool CopyFile(const std::string& src, const std::string& dest) {
    std::ifstream src_file(src, std::ios::binary);
    std::ofstream dest_file(dest, std::ios::binary);
    if (!src_file.is_open() || !dest_file.is_open()) {
        return false;
    }
    dest_file << src_file.rdbuf();
    return true;
}

LinuxNativeEmacsBridge::LinuxNativeEmacsBridge(FlBinaryMessenger* messenger)
    : channel_(nullptr),
      lifecycle_state_("iosmacs Linux native bridge: idle"),
      cols_(80),
      rows_(24),
      input_bytes_(0),
      emacs_pid_(-1),
      master_fd_(-1),
      io_channel_(nullptr),
      io_watch_id_(0),
      child_watch_id_(0) {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    channel_ = fl_method_channel_new(messenger, "iosmacs/native_emacs", FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(channel_, MethodCallCallback, this, nullptr);
}

LinuxNativeEmacsBridge::~LinuxNativeEmacsBridge() {
    StopEmacsProcess();
    if (channel_) {
        g_object_unref(channel_);
        channel_ = nullptr;
    }
}

void LinuxNativeEmacsBridge::MethodCallCallback(FlMethodChannel* channel,
                                               FlMethodCall* method_call,
                                               gpointer user_data) {
    auto* bridge = static_cast<LinuxNativeEmacsBridge*>(user_data);
    bridge->HandleMethodCall(method_call);
}

void LinuxNativeEmacsBridge::HandleMethodCall(FlMethodCall* method_call) {
    const gchar* method = fl_method_call_get_name(method_call);
    if (strcmp(method, "start") == 0) {
        Start(method_call);
    } else if (strcmp(method, "stop") == 0) {
        Stop(method_call);
    } else if (strcmp(method, "redraw") == 0) {
        Redraw(method_call);
    } else if (strcmp(method, "sendBytes") == 0) {
        SendBytes(method_call);
    } else if (strcmp(method, "resize") == 0) {
        Resize(method_call);
    } else if (strcmp(method, "drainOutput") == 0) {
        DrainOutput(method_call);
    } else if (strcmp(method, "listWorkspace") == 0) {
        ListWorkspace(method_call);
    } else if (strcmp(method, "importWorkspace") == 0) {
        ImportWorkspace(method_call);
    } else if (strcmp(method, "exportWorkspace") == 0) {
        ExportWorkspace(method_call);
    } else {
        fl_method_call_respond(method_call, FL_METHOD_RESPONSE(fl_method_not_implemented_response_new()), nullptr);
    }
}

FlValue* LinuxNativeEmacsBridge::GetStatusMap() const {
    FlValue* map = fl_value_new_map();
    fl_value_set_string_take(map, "lifecycleState", fl_value_new_string(lifecycle_state_.c_str()));
    fl_value_set_string_take(map, "cols", fl_value_new_int(cols_));
    fl_value_set_string_take(map, "rows", fl_value_new_int(rows_));
    fl_value_set_string_take(map, "inputBytes", fl_value_new_int(input_bytes_));
    
    size_t count = 0;
    {
        std::lock_guard<std::mutex> lock(output_mutex_);
        count = output_buffer_.size();
    }
    fl_value_set_string_take(map, "outputBytes", fl_value_new_int(count));
    return map;
}

void LinuxNativeEmacsBridge::Start(FlMethodCall* method_call) {
    AppendOutput(reinterpret_cast<const uint8_t*>("Linux native channel is connected.\r\n"), 36);
    if (IsEmacsRunning()) {
        lifecycle_state_ = "iosmacs Linux native bridge: GNU Emacs process running";
        g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(GetStatusMap()));
        fl_method_call_respond(method_call, response, nullptr);
        return;
    }

    if (StartInteractiveEmacsProcess()) {
        g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(GetStatusMap()));
        fl_method_call_respond(method_call, response, nullptr);
        return;
    }

    RunEmacsProcessProbe();
    std::string fallback_msg = "Linux Emacs process unavailable; diagnostic fallback is running.\r\n";
    AppendOutput(reinterpret_cast<const uint8_t*>(fallback_msg.c_str()), fallback_msg.size());
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(GetStatusMap()));
    fl_method_call_respond(method_call, response, nullptr);
}

bool LinuxNativeEmacsBridge::IsEmacsRunning() const {
    if (emacs_pid_ <= 0) return false;
    return kill(emacs_pid_, 0) == 0;
}

bool LinuxNativeEmacsBridge::StartInteractiveEmacsProcess() {
    auto candidates = GetEmacsCandidates();
    std::string candidates_msg = "Linux Emacs process candidates:\r\n";
    AppendOutput(reinterpret_cast<const uint8_t*>(candidates_msg.c_str()), candidates_msg.size());
    for (const auto& candidate : candidates) {
        std::string candidate_line = "- " + candidate + "\r\n";
        AppendOutput(reinterpret_cast<const uint8_t*>(candidate_line.c_str()), candidate_line.size());
    }

    for (const auto& candidate : candidates) {
        if (access(candidate.c_str(), X_OK) == 0) {
            if (LaunchEmacsProcess(candidate)) {
                return true;
            }
        }
    }

    lifecycle_state_ = "iosmacs Linux native bridge: process unavailable";
    return false;
}

bool LinuxNativeEmacsBridge::LaunchEmacsProcess(const std::string& executable_path) {
    int master_fd = -1;
    struct winsize ws = {
        .ws_row = static_cast<unsigned short>(std::max(rows_, 1)),
        .ws_col = static_cast<unsigned short>(std::max(cols_, 1)),
        .ws_xpixel = 0,
        .ws_ypixel = 0
    };

    pid_t child_pid = forkpty(&master_fd, nullptr, nullptr, &ws);
    if (child_pid < 0) {
        std::string err_msg = "Linux forkpty failed: " + std::string(strerror(errno)) + "\r\n";
        AppendOutput(reinterpret_cast<const uint8_t*>(err_msg.c_str()), err_msg.size());
        return false;
    }

    if (child_pid == 0) {
        const char* term_env = getenv("IOSMACS_FLUTTER_TERM");
        if (!term_env || strlen(term_env) == 0) {
            term_env = "xterm-256color";
        }
        setenv("TERM", term_env, 1);
        setenv("COLUMNS", std::to_string(cols_).c_str(), 1);
        setenv("LINES", std::to_string(rows_).c_str(), 1);

        // Apply bundled runtime environment (EMACSLOADPATH, EMACSDATA, etc.)
        auto runtime_env = GetEmacsRuntimeEnvironment(executable_path);
        for (const auto& kv : runtime_env) {
            setenv(kv.first.c_str(), kv.second.c_str(), 1);
        }

        std::string eval_arg = GetRuntimeEvalForm();
        char* argv[] = {
            const_cast<char*>(executable_path.c_str()),
            const_cast<char*>("--quick"),
            const_cast<char*>("--no-splash"),
            const_cast<char*>("-nw"),
            const_cast<char*>("--eval"),
            const_cast<char*>(eval_arg.c_str()),
            nullptr
        };
        execv(executable_path.c_str(), argv);
        _exit(127);
    }

    int flags = fcntl(master_fd, F_GETFL, 0);
    fcntl(master_fd, F_SETFL, flags | O_NONBLOCK);

    emacs_pid_ = child_pid;
    master_fd_ = master_fd;

    g_usleep(750000); // 0.75s probe survival duration

    int wait_status;
    pid_t res = waitpid(child_pid, &wait_status, WNOHANG);
    if (res == child_pid) {
        close(master_fd_);
        emacs_pid_ = -1;
        master_fd_ = -1;
        
        std::string exit_desc = "exit code " + std::to_string(WEXITSTATUS(wait_status));
        if (WIFSIGNALED(wait_status)) {
            exit_desc = "signal " + std::to_string(WTERMSIG(wait_status));
        }
        std::string fail_msg = "Linux interactive GNU Emacs process exited during startup (" + exit_desc + "); trying next candidate: " + executable_path + "\r\n";
        AppendOutput(reinterpret_cast<const uint8_t*>(fail_msg.c_str()), fail_msg.size());
        return false;
    }

    io_channel_ = g_io_channel_unix_new(master_fd_);
    g_io_channel_set_close_on_unref(io_channel_, TRUE);
    g_io_channel_set_encoding(io_channel_, nullptr, nullptr);
    g_io_channel_set_buffered(io_channel_, FALSE);
    io_watch_id_ = g_io_add_watch(io_channel_, G_IO_IN, IoChannelCallback, this);

    child_watch_id_ = g_child_watch_add(emacs_pid_, ChildWatchCallback, this);

    lifecycle_state_ = "iosmacs Linux native bridge: GNU Emacs process running";
    std::string success_msg = "Linux interactive GNU Emacs process started: " + executable_path + "\r\n";
    AppendOutput(reinterpret_cast<const uint8_t*>(success_msg.c_str()), success_msg.size());

    return true;
}

gboolean LinuxNativeEmacsBridge::IoChannelCallback(GIOChannel* source,
                                                   GIOCondition condition,
                                                   gpointer user_data) {
    auto* bridge = static_cast<LinuxNativeEmacsBridge*>(user_data);
    if (condition & G_IO_IN) {
        int fd = g_io_channel_unix_get_fd(source);
        uint8_t buffer[4096];
        ssize_t bytes_read = read(fd, buffer, sizeof(buffer));
        if (bytes_read > 0) {
            bridge->AppendOutput(buffer, bytes_read);
        } else if (bytes_read == 0 || (bytes_read < 0 && errno != EAGAIN && errno != EWOULDBLOCK)) {
            bridge->io_watch_id_ = 0;
            return FALSE;
        }
    }
    return TRUE;
}

void LinuxNativeEmacsBridge::ChildWatchCallback(GPid pid,
                                                gint status,
                                                gpointer user_data) {
    auto* bridge = static_cast<LinuxNativeEmacsBridge*>(user_data);
    g_spawn_close_pid(pid);
    bridge->OnChildExited(status);
}

void LinuxNativeEmacsBridge::OnChildExited(int status) {
    std::string exit_desc = "exit code " + std::to_string(WEXITSTATUS(status));
    if (WIFSIGNALED(status)) {
        exit_desc = "signal " + std::to_string(WTERMSIG(status));
    }
    std::string exit_msg = "Linux Emacs process exited " + exit_desc + "\r\n";
    AppendOutput(reinterpret_cast<const uint8_t*>(exit_msg.c_str()), exit_msg.size());

    lifecycle_state_ = "iosmacs Linux native bridge: process exited " + exit_desc;
    child_watch_id_ = 0;
    CloseEmacsHandles();
    emacs_pid_ = -1;
}

void LinuxNativeEmacsBridge::Stop(FlMethodCall* method_call) {
    StopEmacsProcess();
    lifecycle_state_ = "iosmacs Linux native bridge: stopped";
    std::string stop_msg = "Linux native bridge stopped\r\n";
    AppendOutput(reinterpret_cast<const uint8_t*>(stop_msg.c_str()), stop_msg.size());
    
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(GetStatusMap()));
    fl_method_call_respond(method_call, response, nullptr);
}

void LinuxNativeEmacsBridge::Redraw(FlMethodCall* method_call) {
    uint8_t ff = 0x0c;
    if (WriteToEmacs(&ff, 1)) {
        lifecycle_state_ = "iosmacs Linux native bridge: redraw sent to GNU Emacs";
    } else {
        std::string fallback = "\x0cLinux native bridge redraw; process backend unavailable\r\n";
        AppendOutput(reinterpret_cast<const uint8_t*>(fallback.c_str()), fallback.size());
    }
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(GetStatusMap()));
    fl_method_call_respond(method_call, response, nullptr);
}

void LinuxNativeEmacsBridge::SendBytes(FlMethodCall* method_call) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* bytes_val = fl_value_lookup_string(args, "bytes");
    if (bytes_val && fl_value_get_type(bytes_val) == FL_VALUE_TYPE_UINT8_LIST) {
        size_t len = fl_value_get_length(bytes_val);
        const uint8_t* bytes = fl_value_get_uint8_list(bytes_val);
        input_bytes_ += len;
        if (len > 0) {
            if (!WriteToEmacs(bytes, len)) {
                std::string fallback = "Linux native bridge accepted input; process backend unavailable\r\n";
                AppendOutput(reinterpret_cast<const uint8_t*>(fallback.c_str()), fallback.size());
            } else {
                lifecycle_state_ = "iosmacs Linux native bridge: input sent to GNU Emacs";
            }
        }
    }
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(GetStatusMap()));
    fl_method_call_respond(method_call, response, nullptr);
}

void LinuxNativeEmacsBridge::Resize(FlMethodCall* method_call) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* cols_val = fl_value_lookup_string(args, "cols");
    FlValue* rows_val = fl_value_lookup_string(args, "rows");
    if (cols_val && fl_value_get_type(cols_val) == FL_VALUE_TYPE_INT) {
        cols_ = fl_value_get_int(cols_val);
    }
    if (rows_val && fl_value_get_type(rows_val) == FL_VALUE_TYPE_INT) {
        rows_ = fl_value_get_int(rows_val);
    }

    if (IsEmacsRunning()) {
        ResizeEmacsPty();
        lifecycle_state_ = "iosmacs Linux native bridge: resized GNU Emacs PTY " + std::to_string(cols_) + "x" + std::to_string(rows_);
        std::string resize_msg = "Linux native bridge resized GNU Emacs PTY " + std::to_string(cols_) + "x" + std::to_string(rows_) + "\r\n";
        AppendOutput(reinterpret_cast<const uint8_t*>(resize_msg.c_str()), resize_msg.size());
    } else {
        std::string resize_msg = "Linux native bridge resize " + std::to_string(cols_) + "x" + std::to_string(rows_) + "; process backend unavailable\r\n";
        AppendOutput(reinterpret_cast<const uint8_t*>(resize_msg.c_str()), resize_msg.size());
    }

    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(GetStatusMap()));
    fl_method_call_respond(method_call, response, nullptr);
}

void LinuxNativeEmacsBridge::ResizeEmacsPty() {
    if (master_fd_ < 0) return;
    struct winsize ws = {
        .ws_row = static_cast<unsigned short>(std::max(rows_, 1)),
        .ws_col = static_cast<unsigned short>(std::max(cols_, 1)),
        .ws_xpixel = 0,
        .ws_ypixel = 0
    };
    ioctl(master_fd_, TIOCSWINSZ, &ws);
}

bool LinuxNativeEmacsBridge::WriteToEmacs(const uint8_t* data, size_t size) {
    if (!IsEmacsRunning() || master_fd_ < 0) return false;
    ssize_t written = write(master_fd_, data, size);
    return written == static_cast<ssize_t>(size);
}

void LinuxNativeEmacsBridge::DrainOutput(FlMethodCall* method_call) {
    std::vector<uint8_t> drained;
    {
        std::lock_guard<std::mutex> lock(output_mutex_);
        drained = std::move(output_buffer_);
        output_buffer_.clear();
    }
    g_autoptr(FlValue) result_bytes = fl_value_new_uint8_list(drained.data(), drained.size());
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(result_bytes));
    fl_method_call_respond(method_call, response, nullptr);
}

void LinuxNativeEmacsBridge::RunEmacsProcessProbe() {
    auto candidates = GetEmacsCandidates();
    std::string probe_msg = "Linux Emacs process probe candidates:\r\n";
    AppendOutput(reinterpret_cast<const uint8_t*>(probe_msg.c_str()), probe_msg.size());
    for (const auto& candidate : candidates) {
        std::string candidate_line = "- " + candidate + "\r\n";
        AppendOutput(reinterpret_cast<const uint8_t*>(candidate_line.c_str()), candidate_line.size());
    }

    for (const auto& candidate : candidates) {
        if (access(candidate.c_str(), X_OK) == 0) {
            std::string cmd = candidate + " --batch --quick --eval '(princ \"iosmacs-linux-process-ok\\n\")' 2>&1";
            FILE* pipe = popen(cmd.c_str(), "r");
            if (pipe) {
                char buffer[128];
                std::string result = "";
                while (!feof(pipe)) {
                    if (fgets(buffer, 128, pipe) != nullptr) {
                        result += buffer;
                    }
                }
                int status = pclose(pipe);
                if (status == 0 && result.find("iosmacs-linux-process-ok") != std::string::npos) {
                    lifecycle_state_ = "iosmacs Linux native bridge: process probe ok";
                    std::string ok_msg = "Linux Emacs process probe ok: " + candidate + "\r\n";
                    AppendOutput(reinterpret_cast<const uint8_t*>(ok_msg.c_str()), ok_msg.size());
                    return;
                } else {
                    std::string fail_msg = "Linux Emacs process probe exited with status " + std::to_string(status) + ": " + candidate + "\r\n";
                    AppendOutput(reinterpret_cast<const uint8_t*>(fail_msg.c_str()), fail_msg.size());
                }
            }
        }
    }

    lifecycle_state_ = "iosmacs Linux native bridge: process probe unavailable";
    std::string final_msg = "Linux Emacs process probe unavailable; PTY/process backend remains pending.\r\n";
    AppendOutput(reinterpret_cast<const uint8_t*>(final_msg.c_str()), final_msg.size());
}

void LinuxNativeEmacsBridge::ListWorkspace(FlMethodCall* method_call) {
    std::string workspace_root = PrepareWorkspaceRoot();
    if (workspace_root.empty()) {
        fl_method_call_respond(method_call, FL_METHOD_RESPONSE(fl_method_error_response_new(
            "workspace_unavailable", "Linux workspace root is unavailable", nullptr
        )), nullptr);
        return;
    }

    auto entries = ListDirectory(workspace_root);
    g_autoptr(FlValue) response_list = fl_value_new_list();
    for (const auto& entry : entries) {
        fl_value_append_take(response_list, WorkspaceEntryToFlValue(entry));
    }

    lifecycle_state_ = "iosmacs Linux native bridge: listed " + std::to_string(entries.size()) + " workspace item(s)";
    
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(response_list));
    fl_method_call_respond(method_call, response, nullptr);
}

void LinuxNativeEmacsBridge::ImportWorkspace(FlMethodCall* method_call) {
    std::string workspace_root = PrepareWorkspaceRoot();
    if (workspace_root.empty()) {
        fl_method_call_respond(method_call, FL_METHOD_RESPONSE(fl_method_error_response_new(
            "workspace_unavailable", "Linux workspace root is unavailable", nullptr
        )), nullptr);
        return;
    }

    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* uris_val = fl_value_lookup_string(args, "uris");
    int imported_count = 0;

    if (uris_val && fl_value_get_type(uris_val) == FL_VALUE_TYPE_LIST) {
        size_t len = fl_value_get_length(uris_val);
        for (size_t i = 0; i < len; ++i) {
            FlValue* uri_val = fl_value_get_list_value(uris_val, i);
            if (uri_val && fl_value_get_type(uri_val) == FL_VALUE_TYPE_STRING) {
                std::string uri_str = fl_value_get_string(uri_val);
                std::string src_path = PathFromUri(uri_str);
                std::string dest_path = workspace_root + "/" + GetBaseName(src_path);
                if (CopyFile(src_path, dest_path)) {
                    imported_count++;
                }
            }
        }
    }

    lifecycle_state_ = "iosmacs Linux native bridge: imported " + std::to_string(imported_count) + " workspace item(s)";
    
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(
        fl_value_new_int(imported_count)
    ));
    fl_method_call_respond(method_call, response, nullptr);
}

void LinuxNativeEmacsBridge::ExportWorkspace(FlMethodCall* method_call) {
    std::string workspace_root = PrepareWorkspaceRoot();
    if (workspace_root.empty()) {
        fl_method_call_respond(method_call, FL_METHOD_RESPONSE(fl_method_error_response_new(
            "workspace_unavailable", "Linux workspace root is unavailable", nullptr
        )), nullptr);
        return;
    }

    auto entries = ListDirectory(workspace_root);
    g_autoptr(FlValue) response_list = fl_value_new_list();
    if (entries.empty()) {
        std::string uri = "file://" + workspace_root;
        fl_value_append_take(response_list, fl_value_new_string(uri.c_str()));
    } else {
        for (const auto& entry : entries) {
            std::string uri = "file://" + entry.path;
            fl_value_append_take(response_list, fl_value_new_string(uri.c_str()));
        }
    }

    lifecycle_state_ = "iosmacs Linux native bridge: exported " + std::to_string(fl_value_get_length(response_list)) + " workspace item(s)";
    
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(response_list));
    fl_method_call_respond(method_call, response, nullptr);
}

void LinuxNativeEmacsBridge::StopEmacsProcess() {
    if (emacs_pid_ > 0) {
        kill(emacs_pid_, SIGTERM);
        int status;
        waitpid(emacs_pid_, &status, WNOHANG);
        emacs_pid_ = -1;
    }
    CloseEmacsHandles();
}

void LinuxNativeEmacsBridge::CloseEmacsHandles() {
    if (child_watch_id_ > 0) {
        g_source_remove(child_watch_id_);
        child_watch_id_ = 0;
    }
    if (io_watch_id_ > 0) {
        g_source_remove(io_watch_id_);
        io_watch_id_ = 0;
    }
    if (io_channel_) {
        g_io_channel_unref(io_channel_);
        io_channel_ = nullptr;
    }
    if (master_fd_ >= 0) {
        close(master_fd_);
        master_fd_ = -1;
    }
}

std::vector<std::string> LinuxNativeEmacsBridge::GetEmacsCandidates() const {
    std::vector<std::string> candidates;

    // Prefer bundled Emacs under <exe_dir>/data/iosmacs-emacs/bin/emacs
    char exe_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (len > 0) {
        exe_path[len] = '\0';
        std::string exe_dir(exe_path);
        size_t last_slash = exe_dir.find_last_of('/');
        if (last_slash != std::string::npos) {
            exe_dir = exe_dir.substr(0, last_slash);
        }
        candidates.push_back(exe_dir + "/data/iosmacs-emacs/bin/emacs");
    }

    // Allow explicit override for debug/testing
    const char* env_emacs = getenv("IOSMACS_FLUTTER_EMACS");
    if (env_emacs && strlen(env_emacs) > 0) {
        candidates.push_back(env_emacs);
    }

    return candidates;
}

std::map<std::string, std::string> LinuxNativeEmacsBridge::GetEmacsRuntimeEnvironment(
    const std::string& executable_path) const {
    std::map<std::string, std::string> env;

    // Expect <runtime_root>/bin/emacs layout
    const std::string suffix = "/bin/emacs";
    if (executable_path.size() <= suffix.size()) return env;
    if (executable_path.rfind(suffix) != executable_path.size() - suffix.size()) return env;

    std::string runtime_root = executable_path.substr(0, executable_path.size() - suffix.size());
    std::string lisp_path = runtime_root + "/lisp";

    std::ifstream check(lisp_path + "/loadup.el");
    if (!check.good()) return env;

    env["EMACSLOADPATH"] = lisp_path;
    env["EMACSDATA"] = runtime_root + "/etc";
    env["EMACSDOC"] = runtime_root + "/etc";
    env["EMACSPATH"] = runtime_root + "/libexec";

    return env;
}

std::string LinuxNativeEmacsBridge::GetRuntimeEvalForm() const {
    return "(progn "
           "(when (boundp 'read-extended-command-predicate) "
           "  (setq read-extended-command-predicate nil)) "
           "(when (fboundp 'execute-extended-command) "
           "  (global-set-key (kbd \"M-X\") #'execute-extended-command)) "
           "(autoload 'dired \"dired\" nil t) "
           "(autoload 'tetris \"tetris\" nil t) "
           "(when (fboundp 'xterm-mouse-mode) "
           "  (xterm-mouse-mode 1)))";
}

std::string LinuxNativeEmacsBridge::PrepareWorkspaceRoot() const {
    const char* user_data_dir = g_get_user_data_dir();
    if (!user_data_dir) {
        return "";
    }
    std::string root = std::string(user_data_dir) + "/fluttmacs/workspace";
    if (g_mkdir_with_parents(root.c_str(), 0755) != 0) {
        return "";
    }
    return root;
}

void LinuxNativeEmacsBridge::AppendOutput(const uint8_t* data, size_t size) {
    std::lock_guard<std::mutex> lock(output_mutex_);
    output_buffer_.insert(output_buffer_.end(), data, data + size);
}

