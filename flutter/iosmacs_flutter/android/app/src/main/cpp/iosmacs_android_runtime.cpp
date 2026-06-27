#include <jni.h>

#include <algorithm>
#include <cerrno>
#include <chrono>
#include <csignal>
#include <cstring>
#include <fcntl.h>
#include <mutex>
#include <pty.h>
#include <string>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace {

std::mutex runtime_mutex;
std::string scratch_buffer;
int terminal_cols = 80;
int terminal_rows = 24;
pid_t official_emacs_pid = -1;
int official_emacs_master_fd = -1;
bool official_emacs_suppress_startup_output = false;
std::string official_emacs_startup_buffer;
std::chrono::steady_clock::time_point official_emacs_start_time;

jbyteArray to_byte_array(JNIEnv *env, const std::string &text) {
  auto bytes = env->NewByteArray(static_cast<jsize>(text.size()));
  if (bytes == nullptr) {
    return nullptr;
  }
  env->SetByteArrayRegion(
      bytes,
      0,
      static_cast<jsize>(text.size()),
      reinterpret_cast<const jbyte *>(text.data()));
  return bytes;
}

std::string truncate_to_columns(const std::string &text, int columns) {
  if (columns <= 0 || static_cast<int>(text.size()) <= columns) {
    return text;
  }
  return text.substr(0, static_cast<size_t>(columns));
}

std::string pad_to_columns(const std::string &text, int columns) {
  if (columns <= 0) {
    return text;
  }
  std::string result = truncate_to_columns(text, columns);
  if (static_cast<int>(result.size()) < columns) {
    result.append(static_cast<size_t>(columns - static_cast<int>(result.size())), ' ');
  }
  return result;
}

std::vector<std::string> scratch_lines() {
  std::vector<std::string> lines;
  std::string current;
  for (char ch : scratch_buffer) {
    if (ch == '\n') {
      lines.push_back(current);
      current.clear();
    } else {
      current.push_back(ch);
    }
  }
  lines.push_back(current);
  return lines;
}

std::string render_emacs_frame() {
  const int cols = std::max(20, terminal_cols);
  const int rows = std::max(8, terminal_rows);
  const int body_rows = std::max(1, rows - 4);
  const std::vector<std::string> lines = scratch_lines();
  const int first_line =
      std::max(0, static_cast<int>(lines.size()) - body_rows);

  std::string output;
  output += "\x1B[2J\x1B[H";
  output += pad_to_columns("GNU Emacs 30.2 Android terminal frame", cols);
  output += "\r\n";
  output += pad_to_columns("Buffer: *scratch*   Mode: Lisp Interaction", cols);
  output += "\r\n";

  for (int row = 0; row < body_rows; row++) {
    const int line_index = first_line + row;
    if (line_index < static_cast<int>(lines.size())) {
      output += pad_to_columns(lines[static_cast<size_t>(line_index)], cols);
    } else {
      output += pad_to_columns("", cols);
    }
    output += "\r\n";
  }

  output += "\x1B[7m";
  output += pad_to_columns("-UUU:----F1  *scratch*   Lisp Interaction", cols);
  output += "\x1B[0m\r\n";
  output += pad_to_columns("Android native terminal backend", cols);
  output += "\r\n";
  output += "* ";
  return output;
}

std::string render_terminal_input(JNIEnv *env, jbyteArray input_bytes) {
  if (input_bytes == nullptr) {
    return "";
  }

  const auto length = env->GetArrayLength(input_bytes);
  if (length <= 0) {
    return "";
  }

  std::vector<jbyte> bytes(static_cast<size_t>(length));
  env->GetByteArrayRegion(input_bytes, 0, length, bytes.data());

  for (jbyte byte : bytes) {
    const auto value = static_cast<unsigned char>(byte);
    switch (value) {
      case '\r':
      case '\n':
        scratch_buffer += "\n";
        break;
      case 0x00:
        scratch_buffer += "^@";
        break;
      case 0x1B:
        scratch_buffer += "^[";
        break;
      case 0x7F:
      case 0x08:
        if (!scratch_buffer.empty() && scratch_buffer.back() != '\n') {
          scratch_buffer.pop_back();
        }
        break;
      default:
        if (value >= 0x20 || value == '\t') {
          scratch_buffer.push_back(static_cast<char>(value));
        }
        break;
    }
  }
  return render_emacs_frame();
}

std::string jstring_to_string(JNIEnv *env, jstring value) {
  if (value == nullptr) {
    return "";
  }
  const char *chars = env->GetStringUTFChars(value, nullptr);
  if (chars == nullptr) {
    return "";
  }
  std::string result(chars);
  env->ReleaseStringUTFChars(value, chars);
  return result;
}

void set_nonblocking(int fd) {
  const int flags = fcntl(fd, F_GETFL, 0);
  if (flags >= 0) {
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
  }
}

void update_pty_size_locked() {
  if (official_emacs_master_fd < 0) {
    return;
  }
  winsize size{};
  size.ws_col = static_cast<unsigned short>(std::max(20, terminal_cols));
  size.ws_row = static_cast<unsigned short>(std::max(8, terminal_rows));
  ioctl(official_emacs_master_fd, TIOCSWINSZ, &size);
}

size_t nw_menu_bar_position(const std::string &text) {
  return text.find("File Edit Options Buffers Tools");
}

bool contains_nw_interactive_frame(const std::string &text) {
  return nw_menu_bar_position(text) != std::string::npos
      && text.find("*scratch*") != std::string::npos;
}

std::string tail_from_nw_interactive_frame(const std::string &text) {
  const size_t ready_pos = nw_menu_bar_position(text);
  if (ready_pos == std::string::npos) {
    return text;
  }

  const std::string clear_home = "\x1B[H\x1B[2J";
  const std::string clear_home_alt = "\x1B[2J\x1B[H";
  size_t frame_start = text.rfind(clear_home, ready_pos);
  if (frame_start == std::string::npos) {
    frame_start = text.rfind(clear_home_alt, ready_pos);
  }
  if (frame_start == std::string::npos) {
    frame_start = ready_pos;
  }
  const size_t loading_between = text.find("Loading ", frame_start);
  if (loading_between != std::string::npos && loading_between < ready_pos) {
    return clear_home + text.substr(ready_pos);
  }
  return text.substr(frame_start);
}

std::string release_nw_startup_buffer_locked(const char *reason) {
  const size_t suppressed_bytes = official_emacs_startup_buffer.size();
  std::string output = "\r\niosmacs Android GNU Emacs NW interactive frame ready: ";
  output += reason;
  if (official_emacs_start_time != std::chrono::steady_clock::time_point{}) {
    const auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - official_emacs_start_time);
    output += "; elapsed_ms=";
    output += std::to_string(static_cast<long long>(elapsed.count()));
  }
  output += "; suppressed ";
  output += std::to_string(static_cast<unsigned long long>(suppressed_bytes));
  output += " startup byte(s)\r\n";
  output += tail_from_nw_interactive_frame(official_emacs_startup_buffer);
  official_emacs_startup_buffer.clear();
  official_emacs_suppress_startup_output = false;
  return output;
}

std::string filter_nw_startup_output_locked(const std::string &chunk) {
  if (!official_emacs_suppress_startup_output) {
    return chunk;
  }
  official_emacs_startup_buffer += chunk;
  if (official_emacs_startup_buffer.size() > 262144) {
    official_emacs_startup_buffer.erase(
        0,
        official_emacs_startup_buffer.size() - 262144);
  }
  if (!contains_nw_interactive_frame(official_emacs_startup_buffer)) {
    return "";
  }
  return release_nw_startup_buffer_locked("terminal frame detected");
}

std::string flush_nw_startup_output_locked() {
  if (!official_emacs_suppress_startup_output) {
    return "";
  }
  return release_nw_startup_buffer_locked("startup drain timeout");
}

void reap_official_emacs_locked() {
  if (official_emacs_pid <= 0) {
    return;
  }
  int status = 0;
  const pid_t result = waitpid(official_emacs_pid, &status, WNOHANG);
  if (result == official_emacs_pid) {
    official_emacs_pid = -1;
    if (official_emacs_master_fd >= 0) {
      close(official_emacs_master_fd);
      official_emacs_master_fd = -1;
    }
    official_emacs_suppress_startup_output = false;
    official_emacs_startup_buffer.clear();
    official_emacs_start_time = std::chrono::steady_clock::time_point{};
  }
}

std::string drain_official_emacs_locked() {
  reap_official_emacs_locked();
  if (official_emacs_master_fd < 0) {
    return "";
  }

  std::string output;
  char buffer[4096];
  for (int pass = 0; pass < 64; pass++) {
    const ssize_t count =
        read(official_emacs_master_fd, buffer, sizeof(buffer));
    if (count > 0) {
      output.append(buffer, static_cast<size_t>(count));
      continue;
    }
    if (count == 0) {
      break;
    }
    if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
      break;
    }
    output += "\r\niosmacs Android GNU Emacs PTY read error: ";
    output += std::strerror(errno);
    output += "\r\n";
    break;
  }
  return filter_nw_startup_output_locked(output);
}

void stop_official_emacs_locked() {
  if (official_emacs_pid > 0) {
    kill(official_emacs_pid, SIGTERM);
    for (int attempt = 0; attempt < 20; attempt++) {
      int status = 0;
      const pid_t result = waitpid(official_emacs_pid, &status, WNOHANG);
      if (result == official_emacs_pid) {
        official_emacs_pid = -1;
        break;
      }
      usleep(50000);
    }
    if (official_emacs_pid > 0) {
      kill(official_emacs_pid, SIGKILL);
      waitpid(official_emacs_pid, nullptr, 0);
      official_emacs_pid = -1;
    }
  }
  if (official_emacs_master_fd >= 0) {
    close(official_emacs_master_fd);
    official_emacs_master_fd = -1;
  }
  official_emacs_suppress_startup_output = false;
  official_emacs_startup_buffer.clear();
  official_emacs_start_time = std::chrono::steady_clock::time_point{};
}

}  // namespace

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_iosmacs_1flutter_AndroidNativeEmacsRuntime_start(
    JNIEnv *env,
    jobject /* this */,
    jint cols,
    jint rows) {
  std::lock_guard<std::mutex> lock(runtime_mutex);
  terminal_cols = static_cast<int>(cols);
  terminal_rows = static_cast<int>(rows);
  scratch_buffer.clear();
  return to_byte_array(env, render_emacs_frame());
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_iosmacs_1flutter_AndroidNativeEmacsRuntime_redraw(
    JNIEnv *env,
    jobject /* this */,
    jint cols,
    jint rows) {
  std::lock_guard<std::mutex> lock(runtime_mutex);
  terminal_cols = static_cast<int>(cols);
  terminal_rows = static_cast<int>(rows);
  return to_byte_array(env, render_emacs_frame());
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_iosmacs_1flutter_AndroidNativeEmacsRuntime_sendBytes(
    JNIEnv *env,
    jobject /* this */,
    jbyteArray input_bytes) {
  std::lock_guard<std::mutex> lock(runtime_mutex);
  return to_byte_array(env, render_terminal_input(env, input_bytes));
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_iosmacs_1flutter_AndroidNativeEmacsRuntime_pasteBytes(
    JNIEnv *env,
    jobject /* this */,
    jbyteArray input_bytes) {
  std::lock_guard<std::mutex> lock(runtime_mutex);
  return to_byte_array(env, render_terminal_input(env, input_bytes));
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_iosmacs_1flutter_AndroidNativeEmacsRuntime_startOfficialEmacs(
    JNIEnv *env,
    jobject /* this */,
    jstring executable_path,
    jstring class_path,
    jstring home_dir,
    jstring cache_dir,
    jint cols,
    jint rows) {
  std::lock_guard<std::mutex> lock(runtime_mutex);
  terminal_cols = static_cast<int>(cols);
  terminal_rows = static_cast<int>(rows);
  reap_official_emacs_locked();
  if (official_emacs_pid > 0 && official_emacs_master_fd >= 0) {
    update_pty_size_locked();
    return to_byte_array(env, drain_official_emacs_locked());
  }

  const std::string executable = jstring_to_string(env, executable_path);
  const std::string apk = jstring_to_string(env, class_path);
  const std::string home = jstring_to_string(env, home_dir);
  const std::string cache = jstring_to_string(env, cache_dir);

  if (executable.empty() || apk.empty()) {
    return to_byte_array(
        env,
        "iosmacs Android GNU Emacs PTY session unavailable: missing executable or APK path\r\n");
  }

  winsize size{};
  size.ws_col = static_cast<unsigned short>(std::max(20, terminal_cols));
  size.ws_row = static_cast<unsigned short>(std::max(8, terminal_rows));

  int master_fd = -1;
  const pid_t pid = forkpty(&master_fd, nullptr, nullptr, &size);
  if (pid < 0) {
    std::string message = "iosmacs Android GNU Emacs PTY fork failed: ";
    message += std::strerror(errno);
    message += "\r\n";
    return to_byte_array(env, message);
  }

  if (pid == 0) {
    setenv("EMACS_CLASS_PATH", apk.c_str(), 1);
    setenv("TERM", "xterm-256color", 1);
    setenv("HOME", home.c_str(), 1);
    setenv("TMPDIR", cache.c_str(), 1);
    setenv("COLUMNS", std::to_string(std::max(20, terminal_cols)).c_str(), 1);
    setenv("LINES", std::to_string(std::max(8, terminal_rows)).c_str(), 1);
    const char *argv[] = {
        executable.c_str(),
        "-Q",
        "--no-window-system",
        "--eval",
        "(progn (switch-to-buffer \"*scratch*\") "
        "(insert \"iosmacs official Android PTY ready\\n\") "
        "(redisplay))",
        nullptr,
    };
    execv(executable.c_str(), const_cast<char *const *>(argv));
    _exit(127);
  }

  official_emacs_pid = pid;
  official_emacs_master_fd = master_fd;
  set_nonblocking(official_emacs_master_fd);
  usleep(250000);

  std::string output = "\r\niosmacs Android GNU Emacs PTY session started: pid=";
  output += std::to_string(static_cast<long long>(pid));
  output += "\r\n";
  output += drain_official_emacs_locked();
  return to_byte_array(env, output);
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_iosmacs_1flutter_AndroidNativeEmacsRuntime_sendOfficialBytes(
    JNIEnv *env,
    jobject /* this */,
    jbyteArray input_bytes) {
  std::lock_guard<std::mutex> lock(runtime_mutex);
  if (official_emacs_master_fd < 0) {
    return to_byte_array(env, "");
  }
  const auto length = env->GetArrayLength(input_bytes);
  if (length > 0) {
    std::vector<jbyte> bytes(static_cast<size_t>(length));
    env->GetByteArrayRegion(input_bytes, 0, length, bytes.data());
    write(official_emacs_master_fd, bytes.data(), static_cast<size_t>(length));
    usleep(50000);
  }
  return to_byte_array(env, drain_official_emacs_locked());
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_iosmacs_1flutter_AndroidNativeEmacsRuntime_drainOfficialOutput(
    JNIEnv *env,
    jobject /* this */) {
  std::lock_guard<std::mutex> lock(runtime_mutex);
  return to_byte_array(env, drain_official_emacs_locked());
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_iosmacs_1flutter_AndroidNativeEmacsRuntime_resizeOfficial(
    JNIEnv *env,
    jobject /* this */,
    jint cols,
    jint rows) {
  std::lock_guard<std::mutex> lock(runtime_mutex);
  terminal_cols = static_cast<int>(cols);
  terminal_rows = static_cast<int>(rows);
  update_pty_size_locked();
  if (official_emacs_pid > 0) {
    kill(official_emacs_pid, SIGWINCH);
  }
  usleep(50000);
  return to_byte_array(env, drain_official_emacs_locked());
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_iosmacs_1flutter_AndroidNativeEmacsRuntime_stopOfficialEmacs(
    JNIEnv * /* env */,
    jobject /* this */) {
  std::lock_guard<std::mutex> lock(runtime_mutex);
  stop_official_emacs_locked();
}

// --------------------------------------------------------------------- //
// GNU Emacs NW (no-window-system) text-terminal PTY session             //
// Built without HAVE_ANDROID — no text-terminal restriction.            //
// --------------------------------------------------------------------- //

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_example_iosmacs_1flutter_AndroidNativeEmacsRuntime_startNwEmacs(
    JNIEnv *env,
    jobject /* this */,
    jstring executable_path,
    jstring lisp_dir,
    jstring etc_dir,
    jstring home_dir,
    jstring cache_dir,
    jstring dump_file,
    jint cols,
    jint rows) {
  std::lock_guard<std::mutex> lock(runtime_mutex);
  terminal_cols = static_cast<int>(cols);
  terminal_rows = static_cast<int>(rows);

  // Reap any previous official session first.
  reap_official_emacs_locked();
  if (official_emacs_pid > 0 && official_emacs_master_fd >= 0) {
    update_pty_size_locked();
    return to_byte_array(env, drain_official_emacs_locked());
  }

  const std::string executable = jstring_to_string(env, executable_path);
  const std::string lisp       = jstring_to_string(env, lisp_dir);
  const std::string etc        = jstring_to_string(env, etc_dir);
  const std::string home       = jstring_to_string(env, home_dir);
  const std::string cache      = jstring_to_string(env, cache_dir);
  const std::string dump       = jstring_to_string(env, dump_file);

  if (executable.empty()) {
    return to_byte_array(
        env,
        "iosmacs Android GNU Emacs NW: no executable path\r\n");
  }

  winsize size{};
  size.ws_col = static_cast<unsigned short>(std::max(20, terminal_cols));
  size.ws_row = static_cast<unsigned short>(std::max(8, terminal_rows));

  int master_fd = -1;
  const pid_t pid = forkpty(&master_fd, nullptr, nullptr, &size);
  if (pid < 0) {
    std::string message = "iosmacs Android GNU Emacs NW PTY fork failed: ";
    message += std::strerror(errno);
    message += "\r\n";
    return to_byte_array(env, message);
  }

  if (pid == 0) {
    // Child: set up the environment and exec the NW Emacs binary.
    // EMACSLOADPATH and EMACSDATA tell Emacs where to find its Lisp and etc.
    if (!lisp.empty())
      setenv("EMACSLOADPATH", lisp.c_str(), 1);
    if (!etc.empty())
      setenv("EMACSDATA", etc.c_str(), 1);
    if (!etc.empty())
      setenv("EMACSDOC", etc.c_str(), 1);
    setenv("TERM",    "xterm-256color", 1);
    setenv("TERMINFO", "/dev/null", 1);  // suppress terminfo DB lookup
    if (!home.empty())
      setenv("HOME", home.c_str(), 1);
    if (!cache.empty())
      setenv("TMPDIR", cache.c_str(), 1);
    setenv("COLUMNS", std::to_string(std::max(20, terminal_cols)).c_str(), 1);
    setenv("LINES",   std::to_string(std::max(8, terminal_rows)).c_str(), 1);
    // Disable GUI attempts; force text terminal.
    setenv("DISPLAY", "", 1);
    // Start interactive Emacs in nw mode.
    std::vector<std::string> args;
    args.push_back(executable);
    if (!dump.empty()) {
      args.push_back("--dump-file");
      args.push_back(dump);
    }
    args.push_back("-Q");
    args.push_back("--no-window-system");
    args.push_back("--quick");
    args.push_back("--no-splash");
    args.push_back("--eval");
    args.push_back(
        "(progn "
        "(when (boundp 'read-extended-command-predicate) "
        "(setq read-extended-command-predicate nil)) "
        "(when (fboundp 'execute-extended-command) "
        "(global-set-key (kbd \"M-X\") #'execute-extended-command)) "
        "(autoload 'dired \"dired\" nil t) "
        "(autoload 'tetris \"tetris\" nil t))");
    std::vector<char *> argv;
    argv.reserve(args.size() + 1);
    for (std::string &arg : args) {
      argv.push_back(arg.data());
    }
    argv.push_back(nullptr);
    execv(executable.c_str(), argv.data());
    _exit(127);
  }

  official_emacs_pid = pid;
  official_emacs_master_fd = master_fd;
  official_emacs_suppress_startup_output = true;
  official_emacs_startup_buffer.clear();
  official_emacs_start_time = std::chrono::steady_clock::now();
  set_nonblocking(official_emacs_master_fd);

  std::string output = "\r\niosmacs Android GNU Emacs NW PTY session started: pid=";
  output += std::to_string(static_cast<long long>(pid));
  output += "\r\n";

  // Drain PTY output for up to 8 seconds, checking whether the process
  // is still alive.  Emacs without pdmp emits a long stream of Lisp-loading
  // chatter before the first interactive frame; keep that buffered so Flutter
  // starts rendering at the usable *scratch* frame instead of at loadup noise.
  for (int i = 0; i < 80; i++) {
    usleep(100000);  // 100ms
    std::string chunk = drain_official_emacs_locked();
    if (!chunk.empty()) {
      output += chunk;
    }
    // Check if the process exited early.
    reap_official_emacs_locked();
    if (official_emacs_pid < 0) {
      output += "\r\niosmacs Android GNU Emacs NW process exited early\r\n";
      break;
    }
    // Once the startup filter has released the interactive frame, return early
    // so Flutter can render the usable terminal while Emacs remains alive.
    if (!official_emacs_suppress_startup_output && output.size() > 512) {
      break;
    }
  }
  if (official_emacs_suppress_startup_output) {
    output += flush_nw_startup_output_locked();
  }

  return to_byte_array(env, output);
}
