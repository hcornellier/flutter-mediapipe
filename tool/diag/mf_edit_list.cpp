// Throwaway diagnostic: which Media Foundation layer drops an MP4 edit list?
// Prints the first timestamps IMFSourceReader returns for each file in three
// modes: compressed samples straight from the MPEG-4 source, decoded NV12
// (decoder only), and RGB32 through the video processor, as the gallery's
// video_frames plugin reads them. Also prints the process and OS
// architecture, the Windows build and the versions of the DLLs involved.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>

#include <cstdio>
#include <string>
#include <vector>

#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "version.lib")
#pragma comment(lib, "advapi32.lib")

namespace {

const char* MachineName(USHORT machine) {
  switch (machine) {
    case IMAGE_FILE_MACHINE_AMD64:
      return "x64";
    case IMAGE_FILE_MACHINE_ARM64:
      return "arm64";
    case IMAGE_FILE_MACHINE_I386:
      return "x86";
    default:
      return "other";
  }
}

std::wstring RegistryString(const wchar_t* name) {
  wchar_t buffer[256] = {};
  DWORD size = sizeof(buffer);
  if (RegGetValueW(HKEY_LOCAL_MACHINE,
                   L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", name,
                   RRF_RT_REG_SZ, nullptr, buffer, &size) != ERROR_SUCCESS) {
    return L"?";
  }
  return buffer;
}

DWORD RegistryDword(const wchar_t* name) {
  DWORD value = 0;
  DWORD size = sizeof(value);
  RegGetValueW(HKEY_LOCAL_MACHINE,
               L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", name,
               RRF_RT_REG_DWORD, nullptr, &value, &size);
  return value;
}

std::string FileVersion(const std::wstring& path) {
  DWORD handle = 0;
  const DWORD size = GetFileVersionInfoSizeW(path.c_str(), &handle);
  if (size == 0) return "missing";
  std::vector<BYTE> data(size);
  if (!GetFileVersionInfoW(path.c_str(), 0, size, data.data())) {
    return "unreadable";
  }
  VS_FIXEDFILEINFO* info = nullptr;
  UINT length = 0;
  if (!VerQueryValueW(data.data(), L"\\", reinterpret_cast<void**>(&info),
                      &length) ||
      info == nullptr) {
    return "no-version";
  }
  char text[64];
  snprintf(text, sizeof(text), "%u.%u.%u.%u",
           static_cast<unsigned>(HIWORD(info->dwFileVersionMS)),
           static_cast<unsigned>(LOWORD(info->dwFileVersionMS)),
           static_cast<unsigned>(HIWORD(info->dwFileVersionLS)),
           static_cast<unsigned>(LOWORD(info->dwFileVersionLS)));
  return text;
}

enum class Mode { kCompressed, kDecodedNv12, kProcessedRgb32 };

const char* ModeName(Mode mode) {
  switch (mode) {
    case Mode::kCompressed:
      return "compressed";
    case Mode::kDecodedNv12:
      return "decoded-nv12";
    case Mode::kProcessedRgb32:
      return "processed-rgb32";
  }
  return "?";
}

void Run(const char* arch, const wchar_t* path, Mode mode) {
  const wchar_t* name = wcsrchr(path, L'\\');
  name = name != nullptr ? name + 1 : path;
  printf("MF_DIAG arch=%s file=%ls mode=%s first_us=", arch, name,
         ModeName(mode));
  IMFAttributes* attributes = nullptr;
  HRESULT status = MFCreateAttributes(&attributes, 1);
  if (SUCCEEDED(status) && mode == Mode::kProcessedRgb32) {
    status =
        attributes->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);
  }
  IMFSourceReader* reader = nullptr;
  if (SUCCEEDED(status)) {
    status = MFCreateSourceReaderFromURL(path, attributes, &reader);
  }
  if (attributes != nullptr) attributes->Release();
  if (FAILED(status)) {
    printf("open-failed-0x%08lX\n", static_cast<unsigned long>(status));
    return;
  }
  const DWORD video = static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM);
  reader->SetStreamSelection(static_cast<DWORD>(MF_SOURCE_READER_ALL_STREAMS),
                             FALSE);
  reader->SetStreamSelection(video, TRUE);
  if (mode != Mode::kCompressed) {
    IMFMediaType* type = nullptr;
    status = MFCreateMediaType(&type);
    if (SUCCEEDED(status)) status = type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    if (SUCCEEDED(status)) {
      status = type->SetGUID(MF_MT_SUBTYPE, mode == Mode::kProcessedRgb32
                                                ? MFVideoFormat_RGB32
                                                : MFVideoFormat_NV12);
    }
    if (SUCCEEDED(status)) status = reader->SetCurrentMediaType(video, nullptr, type);
    if (type != nullptr) type->Release();
    if (FAILED(status)) {
      printf("type-failed-0x%08lX\n", static_cast<unsigned long>(status));
      reader->Release();
      return;
    }
  }
  int printed = 0;
  for (int attempt = 0; attempt < 200 && printed < 4; attempt++) {
    DWORD flags = 0;
    LONGLONG timestamp = 0;
    IMFSample* sample = nullptr;
    status = reader->ReadSample(video, 0, nullptr, &flags, &timestamp, &sample);
    if (FAILED(status)) {
      printf("read-failed-0x%08lX", static_cast<unsigned long>(status));
      break;
    }
    if (flags & MF_SOURCE_READERF_ENDOFSTREAM) break;
    if (sample == nullptr) continue;
    // 100-nanosecond units.
    printf("%s%lld", printed == 0 ? "" : ",", timestamp / 10);
    sample->Release();
    printed++;
  }
  printf("\n");
  reader->Release();
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
#if defined(_M_ARM64)
  const char* arch = "arm64";
#elif defined(_M_X64)
  const char* arch = "x64";
#else
  const char* arch = "other";
#endif
  USHORT process_machine = 0;
  USHORT native_machine = 0;
  IsWow64Process2(GetCurrentProcess(), &process_machine, &native_machine);
  printf("MF_DIAG_ENV process=%s native=%s product=\"%ls\" installation=%ls "
         "display=%ls build=%ls.%lu\n",
         arch, MachineName(native_machine),
         RegistryString(L"ProductName").c_str(),
         RegistryString(L"InstallationType").c_str(),
         RegistryString(L"DisplayVersion").c_str(),
         RegistryString(L"CurrentBuild").c_str(),
         static_cast<unsigned long>(RegistryDword(L"UBR")));
  wchar_t system[MAX_PATH] = {};
  GetSystemDirectoryW(system, MAX_PATH);
  for (const wchar_t* dll : {L"mfplat.dll", L"mfreadwrite.dll",
                             L"mfmp4srcsnk.dll", L"msmpeg2vdec.dll",
                             L"msvproc.dll"}) {
    printf("MF_DIAG_DLL process=%s %ls=%s\n", arch, dll,
           FileVersion(std::wstring(system) + L"\\" + dll).c_str());
  }

  if (FAILED(CoInitializeEx(nullptr, COINIT_MULTITHREADED)) ||
      FAILED(MFStartup(MF_VERSION))) {
    printf("MF_DIAG startup failed\n");
    return 1;
  }
  wchar_t loaded[MAX_PATH] = {};
  GetModuleFileNameW(GetModuleHandleW(L"mfplat.dll"), loaded, MAX_PATH);
  printf("MF_DIAG_DLL process=%s loaded mfplat=%ls\n", arch, loaded);

  MFT_REGISTER_TYPE_INFO input = {MFMediaType_Video, MFVideoFormat_H264};
  IMFActivate** decoders = nullptr;
  UINT32 count = 0;
  if (SUCCEEDED(MFTEnumEx(MFT_CATEGORY_VIDEO_DECODER, MFT_ENUM_FLAG_ALL, &input,
                          nullptr, &decoders, &count))) {
    for (UINT32 i = 0; i < count; i++) {
      wchar_t* friendly = nullptr;
      UINT32 length = 0;
      if (SUCCEEDED(decoders[i]->GetAllocatedString(MFT_FRIENDLY_NAME_Attribute,
                                                    &friendly, &length))) {
        printf("MF_DIAG_DECODER process=%s %u: %ls\n", arch, i, friendly);
        CoTaskMemFree(friendly);
      }
      decoders[i]->Release();
    }
    CoTaskMemFree(decoders);
  }

  for (int i = 1; i < argc; i++) {
    for (Mode mode : {Mode::kCompressed, Mode::kDecodedNv12,
                      Mode::kProcessedRgb32}) {
      Run(arch, argv[i], mode);
    }
  }
  MFShutdown();
  CoUninitialize();
  return 0;
}
