/**
 * @file py-pass.cpp
 * @brief Utility to execute a companion Python script with I/O redirection and timeout management.
 *
 * This tool acts as a transparent wrapper for a Python script named identically to the executable 
 * (plus a .py extension). It handles standard stream piping (stdin/stdout/stderr) and 
 * enforces execution limits based on the MAX_EXEC_TIME environment variable.
 *
 * Compilation:
 * @code
 * cl /EHsc /std:c++20 py-pass.cpp
 * x86_64-w64-mingw32-g++ -std=c++20 -O2 -static -o py-pass.exe py-pass.cpp
 * x86_64-w64-mingw32-g++ -std=c++20 -Os -static -s -ffunction-sections -fdata-sections -Wl,--gc-sections -fno-rtti -flto -o py-pass.exe py-pass.cpp
 * @endcode
 */

#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>
#include <thread>
#include <windows.h>

void readFromPipe(HANDLE hPipe, HANDLE hOutput)
{
	char buffer[4096];
	DWORD bytesRead, bytesWritten;

	while (ReadFile(hPipe, buffer, sizeof(buffer), &bytesRead, nullptr) && bytesRead > 0)
	{
		WriteFile(hOutput, buffer, bytesRead, &bytesWritten, nullptr);
	}
}

int main(int argc, char* argv[])
{
	// Get timeout from environment variable
	int timeoutSeconds = 0;
	if (const char* envTimeout = std::getenv("MAX_EXEC_TIME"))
	{
		try
		{
			timeoutSeconds = std::stoi(envTimeout);
		}
		catch (...)
		{
			std::cerr << "Invalid MAX_EXEC_TIME value, using no timeout\n";
		}
	}

	// Get executable path and construct Python script path
	char exePath[MAX_PATH];
	GetModuleFileNameA(nullptr, exePath, MAX_PATH);

	std::filesystem::path scriptPath = std::filesystem::path(exePath).string() + ".py";

	if (!std::filesystem::exists(scriptPath))
	{
		std::cerr << "Error: Python script not found: " << scriptPath << "\n";
		return 1;
	}

	// Build command line: python.exe <script.py> [args...]
	std::string cmdLine = "python.exe \"" + scriptPath.string() + "\"";
	for (int i = 1; i < argc; ++i)
	{
		cmdLine += " ";
		cmdLine += argv[i];
	}

	// Create pipes for stdin, stdout, and stderr
	HANDLE hStdInRead, hStdInWrite;
	HANDLE hStdOutRead, hStdOutWrite;
	HANDLE hStdErrRead, hStdErrWrite;
	SECURITY_ATTRIBUTES sa{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};

	if (!CreatePipe(&hStdInRead, &hStdInWrite, &sa, 0) || !CreatePipe(&hStdOutRead, &hStdOutWrite, &sa, 0) || !CreatePipe(&hStdErrRead, &hStdErrWrite, &sa, 0))
	{
		std::cerr << "Failed to create pipes\n";
		return 1;
	}

	// Ensure parent-side handles are not inherited
	SetHandleInformation(hStdInWrite, HANDLE_FLAG_INHERIT, 0);
	SetHandleInformation(hStdOutRead, HANDLE_FLAG_INHERIT, 0);
	SetHandleInformation(hStdErrRead, HANDLE_FLAG_INHERIT, 0);

	// Setup process startup info
	STARTUPINFOA si{};
	si.cb = sizeof(si);
	si.dwFlags = STARTF_USESTDHANDLES;
	si.hStdInput = hStdInRead;
	si.hStdOutput = hStdOutWrite;
	si.hStdError = hStdErrWrite;

	PROCESS_INFORMATION pi{};

	// Create the child process
	if (!CreateProcessA(nullptr, const_cast<char*>(cmdLine.c_str()), nullptr, nullptr, TRUE, 0, nullptr, nullptr, &si, &pi))
	{
		std::cerr << "Failed to create process. Make sure python.exe is in PATH.\n";
		CloseHandle(hStdInRead);
		CloseHandle(hStdInWrite);
		CloseHandle(hStdOutRead);
		CloseHandle(hStdOutWrite);
		CloseHandle(hStdErrRead);
		CloseHandle(hStdErrWrite);
		return 1;
	}

	// Close child-side handles in parent
	CloseHandle(hStdInRead);
	CloseHandle(hStdOutWrite);
	CloseHandle(hStdErrWrite);

	// Thread to read from child's stdout
	std::thread stdoutThread([hStdOutRead]() {
		readFromPipe(hStdOutRead, GetStdHandle(STD_OUTPUT_HANDLE));
	});

	// Thread to read from child's stderr
	std::thread stderrThread([hStdErrRead]() {
		readFromPipe(hStdErrRead, GetStdHandle(STD_ERROR_HANDLE));
	});

	// Thread to read from our stdin and write to child's stdin
	std::thread stdinThread([hStdInWrite]() {
		char buffer[4096];
		DWORD bytesRead, bytesWritten;
		HANDLE hStdIn = GetStdHandle(STD_INPUT_HANDLE);

		while (ReadFile(hStdIn, buffer, sizeof(buffer), &bytesRead, nullptr) && bytesRead > 0)
		{
			if (!WriteFile(hStdInWrite, buffer, bytesRead, &bytesWritten, nullptr))
			{
				break;
			}
		}
		CloseHandle(hStdInWrite);
	});

	// Wait for process with timeout
	DWORD waitResult;
	if (timeoutSeconds > 0)
	{
		DWORD timeoutMs = timeoutSeconds * 1000;
		waitResult = WaitForSingleObject(pi.hProcess, timeoutMs);

		if (waitResult == WAIT_TIMEOUT)
		{
			std::cerr << "\nProcess terminated after " << timeoutSeconds << " seconds timeout\n";
			TerminateProcess(pi.hProcess, 1);
			WaitForSingleObject(pi.hProcess, INFINITE);
		}
	}
	else
	{
		waitResult = WaitForSingleObject(pi.hProcess, INFINITE);
	}

	// Get exit code
	DWORD exitCode = 0;
	GetExitCodeProcess(pi.hProcess, &exitCode);

	// Cleanup
	CloseHandle(pi.hProcess);
	CloseHandle(pi.hThread);
	CloseHandle(hStdOutRead);
	CloseHandle(hStdErrRead);

	// Wait for I/O threads
	if (stdoutThread.joinable())
	{
		stdoutThread.join();
	}
	if (stderrThread.joinable())
	{
		stderrThread.join();
	}
	if (stdinThread.joinable())
	{
		stdinThread.detach();// Detach as it might be blocked on stdin
	}

	return exitCode;
}