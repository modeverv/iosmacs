#ifndef LINUX_RUNNER_LINUX_NATIVE_EMACS_BRIDGE_H_
#define LINUX_RUNNER_LINUX_NATIVE_EMACS_BRIDGE_H_

#include <flutter_linux/flutter_linux.h>
#include <map>
#include <mutex>
#include <string>
#include <vector>

class LinuxNativeEmacsBridge {
public:
    explicit LinuxNativeEmacsBridge(FlBinaryMessenger* messenger);
    ~LinuxNativeEmacsBridge();

    // Disable copy/move
    LinuxNativeEmacsBridge(const LinuxNativeEmacsBridge&) = delete;
    LinuxNativeEmacsBridge& operator=(const LinuxNativeEmacsBridge&) = delete;

    void HandleMethodCall(FlMethodCall* method_call);
    void AppendOutput(const uint8_t* data, size_t size);
    void OnChildExited(int status);

private:
    // MethodChannel callback
    static void MethodCallCallback(FlMethodChannel* channel,
                                   FlMethodCall* method_call,
                                   gpointer user_data);

    // GLib source callbacks
    static gboolean IoChannelCallback(GIOChannel* source,
                                      GIOCondition condition,
                                      gpointer user_data);
    static void ChildWatchCallback(GPid pid,
                                   gint status,
                                   gpointer user_data);

    // Bridge commands
    void Start(FlMethodCall* method_call);
    void Stop(FlMethodCall* method_call);
    void Redraw(FlMethodCall* method_call);
    void SendBytes(FlMethodCall* method_call);
    void Resize(FlMethodCall* method_call);
    void DrainOutput(FlMethodCall* method_call);
    void ListWorkspace(FlMethodCall* method_call);
    void ImportWorkspace(FlMethodCall* method_call);
    void ExportWorkspace(FlMethodCall* method_call);

    // Helpers
    bool IsEmacsRunning() const;
    bool StartInteractiveEmacsProcess();
    bool LaunchEmacsProcess(const std::string& executable_path);
    void RunEmacsProcessProbe();
    void StopEmacsProcess();
    void CloseEmacsHandles();
    void ResizeEmacsPty();
    bool WriteToEmacs(const uint8_t* data, size_t size);

    std::vector<std::string> GetEmacsCandidates() const;
    std::map<std::string, std::string> GetEmacsRuntimeEnvironment(const std::string& executable_path) const;
    std::string GetRuntimeEvalForm() const;
    std::string PrepareWorkspaceRoot() const;
    FlValue* GetStatusMap() const;

    FlMethodChannel* channel_;
    std::string lifecycle_state_;
    int cols_;
    int rows_;
    int64_t input_bytes_;
    
    // Output buffering
    mutable std::mutex output_mutex_;
    std::vector<uint8_t> output_buffer_;

    // Process & PTY descriptors
    pid_t emacs_pid_;
    int master_fd_;
    GIOChannel* io_channel_;
    guint io_watch_id_;
    guint child_watch_id_;
};

#endif  // LINUX_RUNNER_LINUX_NATIVE_EMACS_BRIDGE_H_
