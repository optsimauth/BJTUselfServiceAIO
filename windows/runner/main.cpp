#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// Flutter 3.47.5 Windows 的 Impeller(OpenGLES) 后端会让进程以 0xC0000005 崩在
// flutter_windows.dll+0x927160，debug 和 profile 模式都复现。引擎在创建时从
// FLUTTER_ENGINE_SWITCHES / FLUTTER_ENGINE_SWITCH_<N> 读开关，所以在引擎起来之前
// 追加 enable-impeller=false，让 flutter run、直接双击 exe、VS 调试都走 Skia。
// 设 AIO_IMPELLER=1 可以恢复 Impeller（当前会崩）。
void ForceSkia() {
  if (::GetEnvironmentVariableW(L"AIO_IMPELLER", nullptr, 0) != 0) {
    return;
  }
  wchar_t buffer[16] = {0};
  DWORD written = ::GetEnvironmentVariableW(L"FLUTTER_ENGINE_SWITCHES", buffer, 16);
  int count = (written > 0 && written < 16) ? _wtoi(buffer) : 0;
  if (count < 0 || count > 8) {
    count = 0;
  }
  wchar_t name[40];
  swprintf_s(name, L"FLUTTER_ENGINE_SWITCH_%d", count + 1);
  ::SetEnvironmentVariableW(name, L"enable-impeller=false");
  swprintf_s(buffer, 16, L"%d", count + 1);
  ::SetEnvironmentVariableW(L"FLUTTER_ENGINE_SWITCHES", buffer);
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

  ForceSkia();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"bjtuselfserviceaio", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
