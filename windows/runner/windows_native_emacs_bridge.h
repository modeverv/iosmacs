#ifndef RUNNER_WINDOWS_NATIVE_EMACS_BRIDGE_H_
#define RUNNER_WINDOWS_NATIVE_EMACS_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <windows.h>

#include <atomic>
#include <map>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class WindowsNativeEmacsBridge {
 public:
  explicit WindowsNativeEmacsBridge(flutter::BinaryMessenger* messenger);
  ~WindowsNativeEmacsBridge();

  WindowsNativeEmacsBridge(const WindowsNativeEmacsBridge&) = delete;
  WindowsNativeEmacsBridge& operator=(const WindowsNativeEmacsBridge&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void Start(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Stop(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Redraw(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SendBytes(
      const flutter::EncodableValue* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Resize(
      const flutter::EncodableValue* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DrainOutput(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ListWorkspace(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ImportWorkspace(
      const flutter::EncodableValue* args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ExportWorkspace(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SelectWorkspaceRoot(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ClearWorkspaceRoot(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  bool IsEmacsRunning() const;
  bool StartInteractiveEmacsProcess();
  bool LaunchEmacsProcess(const std::wstring& executable_path);
  void RunEmacsProcessProbe();
  void StopEmacsProcess();
  void CloseEmacsHandles();
  bool WriteToEmacs(const uint8_t* data, size_t size);
  void ReaderThread();

  std::vector<std::wstring> GetEmacsCandidates() const;
  std::wstring GetExecutableDir() const;
  std::wstring PrepareWorkspaceRoot() const;
  std::string GetRuntimeEvalForm() const;
  std::map<std::wstring, std::wstring> GetEmacsRuntimeEnvironment(
      const std::wstring& executable_path) const;
  std::wstring BuildEnvironmentBlock(
      const std::map<std::wstring, std::wstring>& overrides) const;

  flutter::EncodableMap GetStatusMap() const;
  void AppendOutput(const uint8_t* data, size_t size);
  void AppendOutputStr(const std::string& str);

  // Conversion helpers
  static std::string WideToUtf8(const std::wstring& wide);
  static std::wstring Utf8ToWide(const std::string& utf8);
  static std::string PathFromUri(const std::string& uri);
  static std::string GetBaseName(const std::string& path);
  static bool CopyFileToWorkspace(const std::string& src,
                                  const std::string& dest);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::string lifecycle_state_;
  int cols_;
  int rows_;
  int64_t input_bytes_;

  mutable std::mutex output_mutex_;
  std::vector<uint8_t> output_buffer_;

  // ConPTY
  HPCON pseudo_console_ = nullptr;

  // Child process
  HANDLE process_handle_ = INVALID_HANDLE_VALUE;
  HANDLE thread_handle_ = INVALID_HANDLE_VALUE;
  DWORD process_id_ = 0;

  // Pipes: write to emacs input, read from emacs output
  HANDLE pipe_write_ = INVALID_HANDLE_VALUE;   // we write -> emacs reads
  HANDLE pipe_read_ = INVALID_HANDLE_VALUE;    // emacs writes -> we read

  // Background reader thread
  std::thread reader_thread_;
  std::atomic<bool> reader_running_{false};
};

#endif  // RUNNER_WINDOWS_NATIVE_EMACS_BRIDGE_H_
