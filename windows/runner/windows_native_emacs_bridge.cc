#include "windows_native_emacs_bridge.h"

#include <flutter/standard_method_codec.h>
#include <shlobj.h>

#include <algorithm>
#include <cstring>
#include <fstream>
#include <sstream>

// ---------------------------------------------------------------------------
// Local helpers
// ---------------------------------------------------------------------------

struct WorkspaceEntry {
  std::wstring name;
  std::wstring path;
  bool is_directory;
  int64_t size_bytes;
};

static std::vector<WorkspaceEntry> ListDirectoryW(const std::wstring& path) {
  std::vector<WorkspaceEntry> entries;
  std::wstring pattern = path + L"\\*";
  WIN32_FIND_DATAW fd;
  HANDLE hFind = FindFirstFileW(pattern.c_str(), &fd);
  if (hFind == INVALID_HANDLE_VALUE) return entries;

  do {
    std::wstring name = fd.cFileName;
    if (name == L"." || name == L"..") continue;
    std::wstring full_path = path + L"\\" + name;
    bool is_dir = (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    int64_t size = 0;
    if (!is_dir) {
      size = (static_cast<int64_t>(fd.nFileSizeHigh) << 32) | fd.nFileSizeLow;
    }
    entries.push_back({name, full_path, is_dir, size});
  } while (FindNextFileW(hFind, &fd));

  FindClose(hFind);
  std::sort(entries.begin(), entries.end(),
            [](const WorkspaceEntry& a, const WorkspaceEntry& b) {
              return a.name < b.name;
            });
  return entries;
}

// ---------------------------------------------------------------------------
// WindowsNativeEmacsBridge
// ---------------------------------------------------------------------------

WindowsNativeEmacsBridge::WindowsNativeEmacsBridge(
    flutter::BinaryMessenger* messenger)
    : lifecycle_state_("iosmacs Windows native bridge: idle"),
      cols_(80),
      rows_(24),
      input_bytes_(0) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "iosmacs/native_emacs",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });
}

WindowsNativeEmacsBridge::~WindowsNativeEmacsBridge() {
  StopEmacsProcess();
}

// ---------------------------------------------------------------------------
// Method dispatch
// ---------------------------------------------------------------------------

void WindowsNativeEmacsBridge::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "start") {
    Start(std::move(result));
  } else if (method == "stop") {
    Stop(std::move(result));
  } else if (method == "redraw") {
    Redraw(std::move(result));
  } else if (method == "sendBytes") {
    SendBytes(call.arguments(), std::move(result));
  } else if (method == "resize") {
    Resize(call.arguments(), std::move(result));
  } else if (method == "drainOutput") {
    DrainOutput(std::move(result));
  } else if (method == "listWorkspace") {
    ListWorkspace(std::move(result));
  } else if (method == "importWorkspace") {
    ImportWorkspace(call.arguments(), std::move(result));
  } else if (method == "exportWorkspace") {
    ExportWorkspace(std::move(result));
  } else if (method == "selectWorkspaceRoot") {
    SelectWorkspaceRoot(std::move(result));
  } else if (method == "clearWorkspaceRoot") {
    ClearWorkspaceRoot(std::move(result));
  } else if (method == "showKeyboard") {
    result->Success();
  } else {
    result->NotImplemented();
  }
}

// ---------------------------------------------------------------------------
// Status map
// ---------------------------------------------------------------------------

flutter::EncodableMap WindowsNativeEmacsBridge::GetStatusMap() const {
  size_t out_count = 0;
  {
    std::lock_guard<std::mutex> lock(output_mutex_);
    out_count = output_buffer_.size();
  }
  return flutter::EncodableMap{
      {flutter::EncodableValue("lifecycleState"),
       flutter::EncodableValue(lifecycle_state_)},
      {flutter::EncodableValue("cols"), flutter::EncodableValue(cols_)},
      {flutter::EncodableValue("rows"), flutter::EncodableValue(rows_)},
      {flutter::EncodableValue("inputBytes"),
       flutter::EncodableValue(input_bytes_)},
      {flutter::EncodableValue("outputBytes"),
       flutter::EncodableValue(static_cast<int64_t>(out_count))},
  };
}

// ---------------------------------------------------------------------------
// start
// ---------------------------------------------------------------------------

void WindowsNativeEmacsBridge::Start(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  AppendOutputStr("Windows native channel is connected.\r\n");

  if (IsEmacsRunning()) {
    lifecycle_state_ =
        "iosmacs Windows native bridge: GNU Emacs process running";
    result->Success(flutter::EncodableValue(GetStatusMap()));
    return;
  }

  if (StartInteractiveEmacsProcess()) {
    result->Success(flutter::EncodableValue(GetStatusMap()));
    return;
  }

  RunEmacsProcessProbe();
  AppendOutputStr(
      "Windows Emacs process unavailable; diagnostic fallback is running.\r\n");
  result->Success(flutter::EncodableValue(GetStatusMap()));
}

bool WindowsNativeEmacsBridge::IsEmacsRunning() const {
  if (process_handle_ == INVALID_HANDLE_VALUE) return false;
  DWORD exit_code = 0;
  if (!GetExitCodeProcess(process_handle_, &exit_code)) return false;
  return exit_code == STILL_ACTIVE;
}

bool WindowsNativeEmacsBridge::StartInteractiveEmacsProcess() {
  auto candidates = GetEmacsCandidates();
  AppendOutputStr("Windows Emacs process candidates:\r\n");
  for (const auto& c : candidates) {
    AppendOutputStr("- " + WideToUtf8(c) + "\r\n");
  }

  for (const auto& candidate : candidates) {
    DWORD attr = GetFileAttributesW(candidate.c_str());
    if (attr == INVALID_FILE_ATTRIBUTES) continue;
    if (LaunchEmacsProcess(candidate)) return true;
  }

  lifecycle_state_ = "iosmacs Windows native bridge: process unavailable";
  return false;
}

bool WindowsNativeEmacsBridge::LaunchEmacsProcess(
    const std::wstring& executable_path) {
  // ----------------------------------------------------------------
  // 1. Create pipe pair for the pseudo-console
  // ----------------------------------------------------------------
  HANDLE pty_read_end = INVALID_HANDLE_VALUE;   // ConPTY reads from here
  HANDLE pty_write_end = INVALID_HANDLE_VALUE;  // ConPTY writes to here
  HANDLE app_write = INVALID_HANDLE_VALUE;      // we write to Emacs
  HANDLE app_read = INVALID_HANDLE_VALUE;       // we read from Emacs

  // Pipe: host writes -> ConPTY input
  if (!CreatePipe(&pty_read_end, &app_write, nullptr, 0)) {
    AppendOutputStr("Windows CreatePipe (input) failed\r\n");
    return false;
  }
  // Pipe: ConPTY output -> host reads
  if (!CreatePipe(&app_read, &pty_write_end, nullptr, 0)) {
    CloseHandle(pty_read_end);
    CloseHandle(app_write);
    AppendOutputStr("Windows CreatePipe (output) failed\r\n");
    return false;
  }

  // ----------------------------------------------------------------
  // 2. Create pseudo console
  // ----------------------------------------------------------------
  COORD size = {static_cast<SHORT>(std::max(cols_, 1)),
                static_cast<SHORT>(std::max(rows_, 1))};
  HPCON hPC = nullptr;
  HRESULT hr = CreatePseudoConsole(size, pty_read_end, pty_write_end, 0, &hPC);
  CloseHandle(pty_read_end);
  CloseHandle(pty_write_end);

  if (FAILED(hr)) {
    CloseHandle(app_write);
    CloseHandle(app_read);
    AppendOutputStr("Windows CreatePseudoConsole failed: hr=" +
                    std::to_string(hr) + "\r\n");
    return false;
  }

  // ----------------------------------------------------------------
  // 3. Build process startup attributes with pseudoconsole
  // ----------------------------------------------------------------
  SIZE_T attr_size = 0;
  InitializeProcThreadAttributeList(nullptr, 1, 0, &attr_size);
  std::vector<BYTE> attr_buf(attr_size);
  LPPROC_THREAD_ATTRIBUTE_LIST attr_list =
      reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attr_buf.data());
  if (!InitializeProcThreadAttributeList(attr_list, 1, 0, &attr_size)) {
    ClosePseudoConsole(hPC);
    CloseHandle(app_write);
    CloseHandle(app_read);
    AppendOutputStr("Windows InitializeProcThreadAttributeList failed\r\n");
    return false;
  }
  UpdateProcThreadAttribute(attr_list, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
                             hPC, sizeof(hPC), nullptr, nullptr);

  // ----------------------------------------------------------------
  // 4. Build environment block with runtime overrides
  // ----------------------------------------------------------------
  auto runtime_env = GetEmacsRuntimeEnvironment(executable_path);
  // Add TERM so Emacs knows it's in an xterm-like environment
  runtime_env[L"TERM"] = L"xterm-256color";
  runtime_env[L"COLUMNS"] = std::to_wstring(cols_);
  runtime_env[L"LINES"] = std::to_wstring(rows_);
  std::wstring env_block = BuildEnvironmentBlock(runtime_env);

  // ----------------------------------------------------------------
  // 5. Build command line
  // ----------------------------------------------------------------
  std::string eval_form = GetRuntimeEvalForm();
  std::wstring eval_wide = Utf8ToWide(eval_form);
  // Escape inner double quotes with backslash for Windows CRT argument parsing.
  std::wstring eval_escaped;
  for (wchar_t ch : eval_wide) {
    if (ch == L'"') eval_escaped += L'\\';
    eval_escaped += ch;
  }
  std::wstring cmd = L"\"" + executable_path + L"\"" +
                     L" --quick --no-splash -nw --eval \"" + eval_escaped + L"\"";
  std::vector<wchar_t> cmd_buf(cmd.begin(), cmd.end());
  cmd_buf.push_back(L'\0');

  // ----------------------------------------------------------------
  // 6. Create process
  // ----------------------------------------------------------------
  STARTUPINFOEXW si = {};
  si.StartupInfo.cb = sizeof(si);
  si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
  si.lpAttributeList = attr_list;

  PROCESS_INFORMATION pi = {};
  BOOL ok = CreateProcessW(
      nullptr,          // lpApplicationName
      cmd_buf.data(),   // lpCommandLine
      nullptr,          // lpProcessAttributes
      nullptr,          // lpThreadAttributes
      FALSE,            // bInheritHandles
      EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT |
          CREATE_NO_WINDOW,       // dwCreationFlags
      env_block.empty()           // lpEnvironment
          ? nullptr
          : static_cast<LPVOID>(const_cast<wchar_t*>(env_block.data())),
      nullptr,                    // lpCurrentDirectory
      &si.StartupInfo,            // lpStartupInfo
      &pi);

  DeleteProcThreadAttributeList(attr_list);

  if (!ok) {
    ClosePseudoConsole(hPC);
    CloseHandle(app_write);
    CloseHandle(app_read);
    DWORD err = GetLastError();
    AppendOutputStr("Windows CreateProcessW failed: err=" +
                    std::to_string(err) + " exe=" +
                    WideToUtf8(executable_path) + "\r\n");
    return false;
  }

  // ----------------------------------------------------------------
  // 7. Give process a moment to survive startup
  // ----------------------------------------------------------------
  DWORD wait_result = WaitForSingleObject(pi.hProcess, 750);
  if (wait_result == WAIT_OBJECT_0) {
    // Process exited immediately
    DWORD exit_code = 0;
    GetExitCodeProcess(pi.hProcess, &exit_code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    ClosePseudoConsole(hPC);
    CloseHandle(app_write);
    CloseHandle(app_read);
    AppendOutputStr("Windows Emacs process exited during startup: exit=" +
                    std::to_string(exit_code) +
                    "; trying next candidate: " + WideToUtf8(executable_path) +
                    "\r\n");
    return false;
  }

  // ----------------------------------------------------------------
  // 8. Store handles and start reader thread
  // ----------------------------------------------------------------
  pseudo_console_ = hPC;
  process_handle_ = pi.hProcess;
  thread_handle_ = pi.hThread;
  process_id_ = pi.dwProcessId;
  pipe_write_ = app_write;
  pipe_read_ = app_read;

  reader_running_.store(true);
  reader_thread_ = std::thread([this]() { ReaderThread(); });

  lifecycle_state_ =
      "iosmacs Windows native bridge: GNU Emacs process running";
  AppendOutputStr("Windows interactive GNU Emacs process started: " +
                  WideToUtf8(executable_path) + "\r\n");
  return true;
}

void WindowsNativeEmacsBridge::ReaderThread() {
  const DWORD kBufSize = 4096;
  std::vector<uint8_t> buf(kBufSize);
  while (reader_running_.load()) {
    DWORD bytes_read = 0;
    BOOL ok = ReadFile(pipe_read_, buf.data(), kBufSize, &bytes_read, nullptr);
    if (!ok || bytes_read == 0) {
      break;
    }
    AppendOutput(buf.data(), bytes_read);
  }
  reader_running_.store(false);
}

// ---------------------------------------------------------------------------
// stop
// ---------------------------------------------------------------------------

void WindowsNativeEmacsBridge::Stop(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  StopEmacsProcess();
  lifecycle_state_ = "iosmacs Windows native bridge: stopped";
  AppendOutputStr("Windows native bridge stopped\r\n");
  result->Success(flutter::EncodableValue(GetStatusMap()));
}

void WindowsNativeEmacsBridge::StopEmacsProcess() {
  reader_running_.store(false);

  if (process_handle_ != INVALID_HANDLE_VALUE) {
    TerminateProcess(process_handle_, 0);
    WaitForSingleObject(process_handle_, 2000);
  }

  CloseEmacsHandles();

  if (reader_thread_.joinable()) {
    reader_thread_.join();
  }
}

void WindowsNativeEmacsBridge::CloseEmacsHandles() {
  if (pseudo_console_ != nullptr) {
    ClosePseudoConsole(pseudo_console_);
    pseudo_console_ = nullptr;
  }
  auto close_handle = [](HANDLE& h) {
    if (h != INVALID_HANDLE_VALUE) {
      CloseHandle(h);
      h = INVALID_HANDLE_VALUE;
    }
  };
  close_handle(process_handle_);
  close_handle(thread_handle_);
  close_handle(pipe_write_);
  close_handle(pipe_read_);
  process_id_ = 0;
}

// ---------------------------------------------------------------------------
// redraw
// ---------------------------------------------------------------------------

void WindowsNativeEmacsBridge::Redraw(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  uint8_t ff = 0x0c;
  if (WriteToEmacs(&ff, 1)) {
    lifecycle_state_ =
        "iosmacs Windows native bridge: redraw sent to GNU Emacs";
  } else {
    AppendOutputStr(
        "\x0cWindows native bridge redraw; process backend unavailable\r\n");
  }
  result->Success(flutter::EncodableValue(GetStatusMap()));
}

// ---------------------------------------------------------------------------
// sendBytes
// ---------------------------------------------------------------------------

void WindowsNativeEmacsBridge::SendBytes(
    const flutter::EncodableValue* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (args) {
    const auto* map = std::get_if<flutter::EncodableMap>(args);
    if (map) {
      auto it = map->find(flutter::EncodableValue("bytes"));
      if (it != map->end()) {
        const auto* bytes_vec =
            std::get_if<std::vector<uint8_t>>(&it->second);
        if (bytes_vec && !bytes_vec->empty()) {
          input_bytes_ += static_cast<int64_t>(bytes_vec->size());
          if (!WriteToEmacs(bytes_vec->data(), bytes_vec->size())) {
            AppendOutputStr(
                "Windows native bridge accepted input; process backend "
                "unavailable\r\n");
          } else {
            lifecycle_state_ =
                "iosmacs Windows native bridge: input sent to GNU Emacs";
          }
        }
      }
    }
  }
  result->Success(flutter::EncodableValue(GetStatusMap()));
}

bool WindowsNativeEmacsBridge::WriteToEmacs(const uint8_t* data, size_t size) {
  if (!IsEmacsRunning() || pipe_write_ == INVALID_HANDLE_VALUE) return false;
  DWORD written = 0;
  return WriteFile(pipe_write_, data, static_cast<DWORD>(size), &written,
                   nullptr) &&
         written == static_cast<DWORD>(size);
}

// ---------------------------------------------------------------------------
// resize
// ---------------------------------------------------------------------------

void WindowsNativeEmacsBridge::Resize(
    const flutter::EncodableValue* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (args) {
    const auto* map = std::get_if<flutter::EncodableMap>(args);
    if (map) {
      auto it_cols = map->find(flutter::EncodableValue("cols"));
      auto it_rows = map->find(flutter::EncodableValue("rows"));
      if (it_cols != map->end()) {
        if (const auto* v = std::get_if<int>(&it_cols->second)) cols_ = *v;
      }
      if (it_rows != map->end()) {
        if (const auto* v = std::get_if<int>(&it_rows->second)) rows_ = *v;
      }
    }
  }

  if (IsEmacsRunning() && pseudo_console_ != nullptr) {
    COORD size = {static_cast<SHORT>(std::max(cols_, 1)),
                  static_cast<SHORT>(std::max(rows_, 1))};
    ResizePseudoConsole(pseudo_console_, size);
    lifecycle_state_ = "iosmacs Windows native bridge: resized GNU Emacs PTY " +
                       std::to_string(cols_) + "x" + std::to_string(rows_);
    AppendOutputStr("Windows native bridge resized GNU Emacs PTY " +
                    std::to_string(cols_) + "x" + std::to_string(rows_) +
                    "\r\n");
  } else {
    AppendOutputStr("Windows native bridge resize " + std::to_string(cols_) +
                    "x" + std::to_string(rows_) +
                    "; process backend unavailable\r\n");
  }
  result->Success(flutter::EncodableValue(GetStatusMap()));
}

// ---------------------------------------------------------------------------
// drainOutput
// ---------------------------------------------------------------------------

void WindowsNativeEmacsBridge::DrainOutput(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<uint8_t> drained;
  {
    std::lock_guard<std::mutex> lock(output_mutex_);
    drained = std::move(output_buffer_);
    output_buffer_.clear();
  }
  result->Success(flutter::EncodableValue(drained));
}

// ---------------------------------------------------------------------------
// Workspace operations
// ---------------------------------------------------------------------------

void WindowsNativeEmacsBridge::ListWorkspace(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::wstring root = PrepareWorkspaceRoot();
  if (root.empty()) {
    result->Error("workspace_unavailable",
                  "Windows workspace root is unavailable");
    return;
  }

  auto entries = ListDirectoryW(root);
  flutter::EncodableList list;
  for (const auto& e : entries) {
    list.emplace_back(flutter::EncodableMap{
        {flutter::EncodableValue("name"),
         flutter::EncodableValue(WideToUtf8(e.name))},
        {flutter::EncodableValue("path"),
         flutter::EncodableValue(WideToUtf8(e.path))},
        {flutter::EncodableValue("isDirectory"),
         flutter::EncodableValue(e.is_directory)},
        {flutter::EncodableValue("sizeBytes"),
         flutter::EncodableValue(e.size_bytes)},
    });
  }

  lifecycle_state_ = "iosmacs Windows native bridge: listed " +
                     std::to_string(entries.size()) + " workspace item(s)";
  result->Success(flutter::EncodableValue(list));
}

void WindowsNativeEmacsBridge::ImportWorkspace(
    const flutter::EncodableValue* args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::wstring root = PrepareWorkspaceRoot();
  if (root.empty()) {
    result->Error("workspace_unavailable",
                  "Windows workspace root is unavailable");
    return;
  }

  int imported_count = 0;
  if (args) {
    const auto* map = std::get_if<flutter::EncodableMap>(args);
    if (map) {
      auto it = map->find(flutter::EncodableValue("uris"));
      if (it != map->end()) {
        const auto* list = std::get_if<flutter::EncodableList>(&it->second);
        if (list) {
          for (const auto& item : *list) {
            const auto* uri_str = std::get_if<std::string>(&item);
            if (!uri_str) continue;
            std::string src = PathFromUri(*uri_str);
            std::string dest =
                WideToUtf8(root) + "\\" + GetBaseName(src);
            if (CopyFileToWorkspace(src, dest)) ++imported_count;
          }
        }
      }
    }
  }

  lifecycle_state_ = "iosmacs Windows native bridge: imported " +
                     std::to_string(imported_count) + " workspace item(s)";
  result->Success(flutter::EncodableValue(imported_count));
}

void WindowsNativeEmacsBridge::ExportWorkspace(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::wstring root = PrepareWorkspaceRoot();
  if (root.empty()) {
    result->Error("workspace_unavailable",
                  "Windows workspace root is unavailable");
    return;
  }

  auto entries = ListDirectoryW(root);
  flutter::EncodableList uris;
  if (entries.empty()) {
    uris.emplace_back(
        flutter::EncodableValue("file:///" + WideToUtf8(root)));
  } else {
    for (const auto& e : entries) {
      uris.emplace_back(
          flutter::EncodableValue("file:///" + WideToUtf8(e.path)));
    }
  }

  lifecycle_state_ = "iosmacs Windows native bridge: exported " +
                     std::to_string(uris.size()) + " workspace item(s)";
  result->Success(flutter::EncodableValue(uris));
}

void WindowsNativeEmacsBridge::SelectWorkspaceRoot(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableMap response{
      {flutter::EncodableValue("message"),
       flutter::EncodableValue(
           "Windows workspace root selection pending; native picker not yet "
           "wired")}};
  result->Success(flutter::EncodableValue(response));
}

void WindowsNativeEmacsBridge::ClearWorkspaceRoot(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableMap response{
      {flutter::EncodableValue("message"),
       flutter::EncodableValue("Windows default workspace pending")}};
  result->Success(flutter::EncodableValue(response));
}

// ---------------------------------------------------------------------------
// Process probe
// ---------------------------------------------------------------------------

void WindowsNativeEmacsBridge::RunEmacsProcessProbe() {
  auto candidates = GetEmacsCandidates();
  AppendOutputStr("Windows Emacs process probe candidates:\r\n");
  for (const auto& c : candidates) {
    AppendOutputStr("- " + WideToUtf8(c) + "\r\n");
  }

  for (const auto& candidate : candidates) {
    DWORD attr = GetFileAttributesW(candidate.c_str());
    if (attr == INVALID_FILE_ATTRIBUTES) continue;

    // Run batch probe
    std::wstring cmd = L"\"" + candidate +
                       L"\" --batch --quick --eval "
                       L"\"(princ \\\"iosmacs-windows-process-ok\\\\n\\\")\"";
    std::vector<wchar_t> cmd_buf(cmd.begin(), cmd.end());
    cmd_buf.push_back(L'\0');

    HANDLE pipe_r = INVALID_HANDLE_VALUE, pipe_w = INVALID_HANDLE_VALUE;
    SECURITY_ATTRIBUTES sa = {sizeof(sa), nullptr, TRUE};
    CreatePipe(&pipe_r, &pipe_w, &sa, 0);
    SetHandleInformation(pipe_r, HANDLE_FLAG_INHERIT, 0);

    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdOutput = pipe_w;
    si.hStdError = pipe_w;

    PROCESS_INFORMATION pi = {};
    BOOL ok = CreateProcessW(nullptr, cmd_buf.data(), nullptr, nullptr, TRUE,
                             CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi);
    CloseHandle(pipe_w);

    if (!ok) {
      CloseHandle(pipe_r);
      continue;
    }

    WaitForSingleObject(pi.hProcess, 5000);
    DWORD exit_code = 0;
    GetExitCodeProcess(pi.hProcess, &exit_code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    // Read output
    std::string probe_out;
    char buf[128];
    DWORD bytes_read;
    while (ReadFile(pipe_r, buf, sizeof(buf) - 1, &bytes_read, nullptr) &&
           bytes_read > 0) {
      buf[bytes_read] = '\0';
      probe_out += buf;
    }
    CloseHandle(pipe_r);

    if (exit_code == 0 &&
        probe_out.find("iosmacs-windows-process-ok") != std::string::npos) {
      lifecycle_state_ = "iosmacs Windows native bridge: process probe ok";
      AppendOutputStr("Windows Emacs process probe ok: " +
                      WideToUtf8(candidate) + "\r\n");
      return;
    }
    AppendOutputStr("Windows Emacs process probe exited " +
                    std::to_string(exit_code) + ": " +
                    WideToUtf8(candidate) + "\r\n");
  }

  lifecycle_state_ =
      "iosmacs Windows native bridge: process probe unavailable";
  AppendOutputStr(
      "Windows Emacs process probe unavailable; PTY/process backend remains "
      "pending.\r\n");
}

// ---------------------------------------------------------------------------
// Candidate discovery
// ---------------------------------------------------------------------------

std::wstring WindowsNativeEmacsBridge::GetExecutableDir() const {
  wchar_t exe_path[MAX_PATH];
  DWORD len = GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  if (len == 0) return L"";
  std::wstring path(exe_path, len);
  size_t last_slash = path.find_last_of(L"\\/");
  if (last_slash == std::wstring::npos) return L"";
  return path.substr(0, last_slash);
}

std::vector<std::wstring> WindowsNativeEmacsBridge::GetEmacsCandidates()
    const {
  std::vector<std::wstring> candidates;

  // Prefer bundled Emacs under <exe_dir>/data/iosmacs-emacs/bin/emacs.exe
  std::wstring exe_dir = GetExecutableDir();
  if (!exe_dir.empty()) {
    candidates.push_back(exe_dir + L"\\data\\iosmacs-emacs\\bin\\emacs.exe");
  }

  // Allow explicit override for debug/testing
  wchar_t env_emacs[MAX_PATH];
  if (GetEnvironmentVariableW(L"IOSMACS_FLUTTER_EMACS", env_emacs, MAX_PATH) >
      0) {
    candidates.push_back(env_emacs);
  }

  return candidates;
}

// ---------------------------------------------------------------------------
// Runtime environment
// ---------------------------------------------------------------------------

std::map<std::wstring, std::wstring>
WindowsNativeEmacsBridge::GetEmacsRuntimeEnvironment(
    const std::wstring& executable_path) const {
  std::map<std::wstring, std::wstring> env;

  const std::wstring suffix = L"\\bin\\emacs.exe";
  if (executable_path.size() <= suffix.size()) return env;
  if (executable_path.rfind(suffix) !=
      executable_path.size() - suffix.size())
    return env;

  std::wstring runtime_root =
      executable_path.substr(0, executable_path.size() - suffix.size());
  std::wstring lisp_path = runtime_root + L"\\lisp";
  std::wstring loadup = lisp_path + L"\\loadup.el";

  DWORD attr = GetFileAttributesW(loadup.c_str());
  if (attr == INVALID_FILE_ATTRIBUTES) return env;

  env[L"EMACSLOADPATH"] = lisp_path;
  env[L"EMACSDATA"] = runtime_root + L"\\etc";
  env[L"EMACSDOC"] = runtime_root + L"\\etc";
  env[L"EMACSPATH"] = runtime_root + L"\\libexec";

  return env;
}

std::wstring WindowsNativeEmacsBridge::BuildEnvironmentBlock(
    const std::map<std::wstring, std::wstring>& overrides) const {
  // Snapshot current environment, apply overrides, build NUL-separated block
  std::map<std::wstring, std::wstring> env_map;

  LPWCH raw = GetEnvironmentStringsW();
  if (raw) {
    LPWCH ptr = raw;
    while (*ptr) {
      std::wstring entry(ptr);
      size_t eq = entry.find(L'=');
      if (eq != std::wstring::npos && eq > 0) {
        std::wstring key = entry.substr(0, eq);
        std::wstring val = entry.substr(eq + 1);
        // Uppercase key for comparison
        std::wstring key_up = key;
        for (auto& ch : key_up) ch = towupper(ch);
        env_map[key_up] = val;  // store with uppercased key
      }
      ptr += entry.size() + 1;
    }
    FreeEnvironmentStringsW(raw);
  }

  // Apply overrides (uppercase key for dedup)
  for (const auto& kv : overrides) {
    std::wstring key_up = kv.first;
    for (auto& ch : key_up) ch = towupper(ch);
    env_map[key_up] = kv.second;
  }

  // Serialize
  std::wstring block;
  for (const auto& kv : env_map) {
    block += kv.first + L"=" + kv.second + L'\0';
  }
  block += L'\0';
  return block;
}

std::string WindowsNativeEmacsBridge::GetRuntimeEvalForm() const {
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

// ---------------------------------------------------------------------------
// Workspace root
// ---------------------------------------------------------------------------

std::wstring WindowsNativeEmacsBridge::PrepareWorkspaceRoot() const {
  wchar_t app_data[MAX_PATH];
  if (FAILED(SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr,
                               SHGFP_TYPE_CURRENT, app_data))) {
    return L"";
  }
  std::wstring root = std::wstring(app_data) + L"\\fluttmacs\\workspace";
  // Create dirs recursively
  std::wstring partial;
  for (wchar_t ch : root) {
    partial += ch;
    if (ch == L'\\') {
      CreateDirectoryW(partial.c_str(), nullptr);
    }
  }
  CreateDirectoryW(root.c_str(), nullptr);
  if (GetFileAttributesW(root.c_str()) == INVALID_FILE_ATTRIBUTES) return L"";
  return root;
}

// ---------------------------------------------------------------------------
// Output buffer
// ---------------------------------------------------------------------------

void WindowsNativeEmacsBridge::AppendOutput(const uint8_t* data, size_t size) {
  std::lock_guard<std::mutex> lock(output_mutex_);
  output_buffer_.insert(output_buffer_.end(), data, data + size);
}

void WindowsNativeEmacsBridge::AppendOutputStr(const std::string& str) {
  AppendOutput(reinterpret_cast<const uint8_t*>(str.data()), str.size());
}

// ---------------------------------------------------------------------------
// Conversion helpers
// ---------------------------------------------------------------------------

std::string WindowsNativeEmacsBridge::WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return "";
  int sz =
      WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                          static_cast<int>(wide.size()), nullptr, 0, nullptr, nullptr);
  if (sz <= 0) return "";
  std::string out(sz, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                      out.data(), sz, nullptr, nullptr);
  return out;
}

std::wstring WindowsNativeEmacsBridge::Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return L"";
  int sz = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                               static_cast<int>(utf8.size()), nullptr, 0);
  if (sz <= 0) return L"";
  std::wstring out(sz, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      out.data(), sz);
  return out;
}

std::string WindowsNativeEmacsBridge::PathFromUri(const std::string& uri) {
  // file:///C:/path  ->  C:/path
  if (uri.rfind("file:///", 0) == 0) {
    return uri.substr(8);
  }
  if (uri.rfind("file://", 0) == 0) {
    return uri.substr(7);
  }
  return uri;
}

std::string WindowsNativeEmacsBridge::GetBaseName(const std::string& path) {
  size_t last = path.find_last_of("/\\");
  if (last == std::string::npos) return path;
  return path.substr(last + 1);
}

bool WindowsNativeEmacsBridge::CopyFileToWorkspace(const std::string& src,
                                                    const std::string& dest) {
  std::ifstream in(src, std::ios::binary);
  std::ofstream out(dest, std::ios::binary);
  if (!in.is_open() || !out.is_open()) return false;
  out << in.rdbuf();
  return true;
}
