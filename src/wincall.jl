typealias HANDLE Ptr{Void}
typealias DWORD UInt32
typealias WORD UInt16
typealias LPTSTR Cwchar_t
typealias LPBYTE Ptr{Char}

immutable STARTUPINFO
	cb::DWORD
	lpReserved::LPTSTR
	lpDesktop::LPTSTR
	lpTitle::LPTSTR
	dwX::DWORD
	dwY::DWORD
	dwXSize::DWORD
	dwYSize::DWORD
	dwXCountChars::DWORD
	dwYCountChars::DWORD
	dwFillAttribute::DWORD
	dwFlags::DWORD
	wShowWindow::WORD
	cbReserved2::WORD
	lpReserved2::LPBYTE
	hStdInput::HANDLE
	hStdOutput::HANDLE
	hStdError::HANDLE
	STARTUPINFO() = new()
end

immutable PROCESS_INFORMATION
	hProcess::HANDLE
	hThread::HANDLE
	dwProcessId::DWORD
	dwThreadId::DWORD
	PROCESS_INFORMATION() = new(C_NULL,C_NULL,C_NULL,C_NULL)
end

CreateProcess(cmd) = begin
si = [STARTUPINFO()]
	pi = [PROCESS_INFORMATION()]
	ccall(:CreateProcessW, Cchar,
	(Ptr{Cwchar_t}, Ptr{Cwchar_t}, Ptr{Int}, Ptr{Int}, Cchar, Int64,
	Ptr{UInt8}, Ptr{UInt8}, Ptr{PROCESS_INFORMATION}, Ptr{STARTUPINFO}),
	C_NULL,
	utf16(cmd),
	C_NULL,
	C_NULL,
	0,
	0,
	C_NULL, C_NULL,
	convert(Ptr{PROCESS_INFORMATION}, pointer(pi)),
	convert(Ptr{STARTUPINFO}, pointer(pi)))
end 
