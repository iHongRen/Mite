-- Mite 应用外壳：接收拖入的文件，或读取 Finder 当前选中的文件/文件夹。

on run
	-- 点击 Finder 工具栏图标时系统不会传入选中的文件，主动向 Finder 查询
	try
		tell application "Finder"
			set selectedItems to selection as alias list
		end tell
	on error errMsg
		display dialog "无法读取 Finder 选中项：" & errMsg buttons {"好"} default button 1 with title "Mite"
		return
	end try
	if (count of selectedItems) is 0 then
		display dialog "请先在 Finder 中选中 PNG 图片或文件夹，然后再点击 Mite。" buttons {"好"} default button 1 with title "Mite"
		return
	end if
	my processFiles(selectedItems)
end run

on open theFiles
	my processFiles(theFiles)
end open

on processFiles(theFiles)
	set pathArgs to ""
	repeat with f in theFiles
		set pathArgs to pathArgs & " " & quoted form of POSIX path of f
	end repeat
	set runner to POSIX path of (path to resource "main.sh")
	try
		with timeout of 3600 seconds
			do shell script "/bin/bash " & quoted form of runner & pathArgs
		end timeout
	on error errMsg
		display dialog "Mite 运行出错：" & errMsg buttons {"好"} default button 1 with title "Mite"
	end try
end processFiles
