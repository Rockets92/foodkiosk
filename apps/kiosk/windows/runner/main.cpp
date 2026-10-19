#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

// The customer totem fills the primary monitor with no borders and stays
// on top. Start with --windowed for development.
static void EnterKioskFullscreen(HWND hwnd) {
  HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  ::GetMonitorInfo(monitor, &info);
  const RECT& r = info.rcMonitor;
  ::SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP);
  ::SetWindowPos(hwnd, HWND_TOPMOST, r.left, r.top, r.right - r.left,
                 r.bottom - r.top, SWP_FRAMECHANGED);
}

static bool HasFlag(const std::vector<std::string>& args,
                    const std::string& flag) {
  return std::find(args.begin(), args.end(), flag) != args.end();
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  const bool windowed = HasFlag(command_line_arguments, "--windowed");
  const bool hide_cursor = HasFlag(command_line_arguments, "--hide-cursor");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  // Windowed (development/demo): a portrait window like the totem screen.
  Win32Window::Size size(480, 820);
  if (!window.Create(L"Food Kiosk", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  if (!windowed) EnterKioskFullscreen(window.GetHandle());
  if (hide_cursor) ::ShowCursor(FALSE);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
