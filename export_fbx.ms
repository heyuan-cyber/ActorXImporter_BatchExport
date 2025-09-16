/*

 ActorX batch converter for 3ds Max

 Created:	December 15 2010

 Author:	Konstantin Nosov (aka Gildor)

 Web page:	http://www.gildor.org/projects/unactorx

 Revision History:


	09.12.2025 v1.08 -  By Heyuan（and ChatGPT）
	- fix export psa bug ： 路径问题
	- 支持一键导出文件夹下所有psa文件

	06.12.2017 v1.07
	- renamed "recurse" option to "look in subfolders" to be less confising to new users

    20.09.2017 v1.06
    - fixed error in fbx animation export when track has 0 frames

	17.01.2017 v1.05
	- fixed non-multitake animation export
	- fixed length of exported animation

	31.07.2016 v1.04
	- option to save multiple animation is single FBX file (multi-take animation)

	25.07.2016 v1.03
	- saving animation name as FBX Take name (thanks Skykila)

	21.07.2015 v1.02
	- updated to match ActorX Importer 1.33 changes, improved appearance

	29.12.2010 v1.01
	- added output format selection (fbx, ase, max)

	15.12.2010 v1.00
	- first public release

*/


/* TODO
	- save settings to the ActorX Importer ini (using its API)
*/

global g_axImporterVersion

global g_meshDir
global g_meshRecurse
global g_fbxSmGroups
global g_fbxSmMesh
global g_fbxMultiTake
global g_outFormat
global g_useDefaultFBXSettings
global g_exportFolder -- 定义全局变量

if (g_meshDir     == undefined) then g_meshDir     = ""
if (g_meshRecurse == undefined) then g_meshRecurse = false
if (g_fbxSmGroups == undefined) then g_fbxSmGroups = true
if (g_fbxSmMesh   == undefined) then g_fbxSmMesh   = true
if (g_fbxMultiTake == undefined) then g_fbxMultiTake = false
if (g_outFormat   == undefined) then g_outFormat   = 1
if (g_useDefaultFBXSettings == undefined) then g_useDefaultFBXSettings = true


fn VerifyAXI =
(
	if (g_axImporterVersion == undefined) then
	(
		messageBox "ActorX 导入器未加载！"
		return false
	)
	if (g_axImporterVersion < 133) then
	(
		messageBox "您的 ActorX 导入器 太旧，请更新！"
		return false
	)
	return true
)


-- configure FBX exporter
fn SetupFBX =
(
	if g_useDefaultFBXSettings then return undefined

	-- http://www.the-area.com/forum/autodesk-fbx/fbx-plug-ins-import-export-discussions/maxscript-export-dialog-properties/
	-- both commands should be used to ensure all commands are functional
	pluginManager.loadClass FBXIMP
	pluginManager.loadClass FBXEXP

	-- FbxExporterSetParam "Geometries" true -- <bool>
	-- Controls the state of the "Geometries" checkbox in the FBX Export dialog.
	FbxExporterSetParam "NormalsPerPoly" true -- <bool>
	-- Controls the state of the "Support normals per polygon vertex" checkbox in the FBX Export dialog.
	FbxExporterSetParam "Cameras" false -- <bool>
	-- Controls the state of the "Cameras" checkbox in the FBX Export dialog.
	FbxExporterSetParam "Lights" false -- <bool>
	-- Controls the state of the "Lights" checkbox in the FBX Export dialog.
	FbxExporterSetParam "GeomAsBone" true -- <bool>
	-- Controls the state of the "Geometries used as bones, exported as bones" checkbox in the FBX Export dialog.
	FbxExporterSetParam "Shape" false -- <bool>
	-- Controls the state of the "Shape (Morph modifier)" checkbox in the FBX Export dialog.
	FbxExporterSetParam "Skin" true -- <bool>
	-- Controls the state of the "Skins (Skin Modifier and Physique)" checkbox in the FBX Export dialog.
	FbxExporterSetParam "Animation" true -- <bool>
	-- Controls the state of the "Animation" checkbox in the FBX Export dialog.
	-- FbxExporterSetParam "Resampling" -- <float>
	-- Controls the value of the "Resampling rate (when necessary)" field in the FBX Export dialog.
	FbxExporterSetParam "ShowWarnings" false -- <bool>
	-- Controls the state of the "Show warnings" checkbox in the FBX Export dialog.
	FbxExporterSetParam "EmbedTextures" false -- <bool>
	-- Controls the state of the "Embed textures in export file" checkbox in the FBX Export dialog.
	FbxExporterSetParam "SmoothingGroups" g_fbxSmGroups -- <bool>
	-- True or false. See Smoothing Groups for an explanation of this setting.
	FbxExporterSetParam "SmoothMeshExport" g_fbxSmMesh -- <bool>
	-- True or false. See TurboSmooth for an explanation of this setting.
)


fn GetExportSubDir =
(
	if (g_outFormat == 1) then
	(
		return "FBX"
	)
	if (g_outFormat == 2) then
	(
		return "ase"
	)
	if (g_outFormat == 3) then
	(
		return "max"
	)
	return "unknown"		-- should not get here
)

-- ---------- 路径清理函数（保留驱动器冒号、保留分隔符；空格删除） ----------
fn sanitizePathForExport origPath =
(
    if origPath == undefined or origPath == "" then return origPath
    local newPath = ""
    local len = origPath.count
    local firstChar = substring origPath 1 1

    for i = 1 to len do
    (
        local c = substring origPath i 1
        local code = bit.charAsInt c

        -- 保留目录分隔符（统一为反斜杠）
        if c == "\\" or c == "/" then
        (
            newPath += "\\"
        )
        if c == "(" or c == ")" then
        (
            newPath += "_"
        )
        -- 删除空格（如需改成下划线，可把下面一行改为 newPath += "_"）
        else if c == " " then
        (
            -- skip
        )
        -- 冒号：仅在驱动器位置保留（例如 "E:"），其它位置全部替换为下划线
        else if c == ":" then
        (
            if (i == 2) and ((firstChar >= "A" and firstChar <= "Z") or (firstChar >= "a" and firstChar <= "z")) then
                newPath += ":"    -- 驱动器冒号保留
            else
                newPath += "_"    -- 其它冒号替换
        )
        -- 常见非法字符替换
        else if (c == "\"" or c == "<" or c == ">" or c == "|" or c == "?" or c == "*") then
        (
            newPath += "_"
        )
        -- 非 ASCII（如中文）替换为下划线
        else if code > 127 then
        (
            newPath += "_"
        )
        else
        (
            newPath += c
        )
    )

    return newPath
)
fn SaveAXFile filename =
(
	if (g_outFormat == 1) then
	(
		-- FBX
		local safePath = sanitizePathForExport filename
		exportFile safePath #noPrompt using:FBXEXP
		return undefined
	)
	if (g_outFormat == 2) then
	(
		-- ASE
		exportFile (filename + ".ase") #noPrompt
		return undefined
	)
	if (g_outFormat == 3) then
	(
		-- MAX
		saveMaxFile filename
		return undefined
	)
)


fn ExportFbxAnim =
(
	if (not VerifyAXI()) then return undefined

	bones = FindAllBones()
	if (bones.count == 0) then
	(
		messageBox "网格体未被加载！"
		return undefined
	)

	if (Anims.count == 0) then
	(
		messageBox "动画集未被加载！"
		return undefined
	)

	SetupFBX()

	-- configure ActorX Importer
	local playAnim = g_playAnim	-- save
	g_playAnim = false

	-- export all animations
	if (g_fbxMultiTake == false) then
	(
		-- 创建导出目录（保留路径，处理子目录名）
		local baseDir = getFilenamePath(AnimFileName) + GetExportSubDir() + "\\"
		makeDir baseDir all:true

		-- 遍历动画
		for i = 1 to Anims.count do
		(
			local track = Anims[i]
			local trackName = track.Name      
			local filename = baseDir + trackName        
			local numFrames = track.NumRawFrames-1
			if (numFrames == 0) then numFrames = 1

			-- clear Take information before the export
			FBXExporterSetParam "SplitAnimationIntoTakes" "-clear"
			FBXExporterSetParam "SplitAnimationIntoTakes" track.Name 0 numFrames
			format "Exporting animation % (% frames) -> %\n" track.Name numFrames filename

			ImportPsaFile AnimFileName i
			SaveAXFile filename
		)
	)
	else
	(
		local dir = getFilenamePath(AnimFileName) + GetExportSubDir()
		makeDir dir all:true
		local filename = dir + "\\" + getFilenameFile(AnimFileName)
		format "Exporting all animations -> %\n" filename
		ImportPsaFile AnimFileName 1 all:true
		for i = 1 to Anims.count do
		(
			local track = Anims[i]
			local trackName = track.Name
			local numFrames = track.NumRawFrames-1
			if (numFrames < 1) then numFrames = 1
			FBXExporterSetParam "SplitAnimationIntoTakes" trackName track.FirstRawFrame (track.FirstRawFrame+numFrames)
		)
		SaveAXFile filename
	)

	-- clear Take information after the export
	FBXExporterSetParam "SplitAnimationIntoTakes" "-clear"

	g_playAnim = playAnim		-- restore
)

-- 全局递归函数
fn ProcessPSAFolder dir prefix =
(
    -- 获取当前目录下所有 PSA 文件
    local psaFiles = getFiles (dir + "\\*.psa")
    if psaFiles.count > 0 then
    (
        SetupFBX() -- 配置 FBX，只在第一次调用即可

        for f in psaFiles do
        (
            AnimFileName = f
            bones = FindAllBones()
            if bones.count == 0 then
            (
                messageBox ("骨骼未加载: " + f)
                continue
            )

            -- 导入 PSA 文件
            ImportPsaFile AnimFileName -1 all:true

            -- 创建输出目录
            local baseDir = getFilenamePath(AnimFileName) + "FBX\\"
            makeDir baseDir all:true

            -- 遍历动画
            for i = 1 to Anims.count do
            (
                local track = Anims[i]
                local safeName = track.Name
                local filename = baseDir + prefix + getFilenameFile(AnimFileName) + "_" + safeName

                format "Exporting animation % -> %\n" track.Name filename

                local numFrames = track.NumRawFrames-1
                if numFrames < 1 then numFrames = 1

                -- 清除旧的 Take 信息
                FBXExporterSetParam "SplitAnimationIntoTakes" "-clear"
                FBXExporterSetParam "SplitAnimationIntoTakes" safeName 0 numFrames
                ImportPsaFile AnimFileName i
                SaveAXFile filename
            )

            -- 清除 Take 信息
            FBXExporterSetParam "SplitAnimationIntoTakes" "-clear"
        )
    )

    -- 递归处理子文件夹
    local excludeDirs = #("facial", "basic") -- 这里写要排除的目录关键字
    
    local subDirs = getDirectories (dir + "\\*")
    for sub in subDirs do
    (
        local subName = getFilenameFile sub
        local skip = false
        
        -- 检查是否在排除列表中
        for ex in excludeDirs do
        (
            if matchPattern subName pattern:("*" + ex + "*") ignoreCase:true then
            (
                skip = true
                exit -- 找到了就不用再继续比对
            )
        )
    
        if not skip do
            ProcessPSAFolder sub prefix
    )
)
fn GetPrefixFromTxt =
(
    local scriptDir = getFilenamePath getSourceFileName() -- 脚本所在目录
    local prefixFile = scriptDir + "prefix.txt"
    local prefix = ""

    if doesFileExist prefixFile then
    (
        local f = openFile prefixFile mode:"rt"
        if f != undefined do
        (
            prefix = trimRight (readLine f) -- 读第一行并去掉末尾空格
            close f
        )
    )
    else
    (
        messageBox ("未找到前缀文件: " + prefixFile + "\n将使用空前缀")
    )
    return prefix
)
-- 主函数：固定前缀
fn ExportPSAFolderToFBX folderPath =
(
    if folderPath == undefined do folderPath = g_exportFolder
    if folderPath == undefined do
    (
        messageBox "未指定导出文件夹"
        return undefined
    )

    if (not VerifyAXI()) then return undefined


    -- 从 txt 读取前缀
    local prefix = GetPrefixFromTxt()

    ProcessPSAFolder folderPath prefix

    messageBox "批量导出完成!"
)


fn ExportFbxMesh psk_filename =
(
	if (not VerifyAXI()) then return undefined
	SetupFBX()

--	format "MESH: %\n" filename

	-- create target directory
	local dir = (getFilenamePath psk_filename) + GetExportSubDir()
	makeDir dir all:true
	local filename = dir + "\\" + getFilenameFile(psk_filename)
	format "Exporting mesh % -> %\n" psk_filename filename

	ClearMaxScene()
	ImportPskFile psk_filename
	SaveAXFile filename
)

fn ExportFbxMeshes path recurse =
(
	if (not VerifyAXI()) then return undefined
--	format "EXPORT DIR % %\n" path recurse

	local files = getFiles(path + "/*.psk*")
	for file in files do ExportFbxMesh file
	if recurse then
	(
		local dirs = getDirectories(path + "/*")
		for dir in dirs do ExportFbxMeshes dir recurse
	)

	ClearMaxScene()
)


-- UI
rollout fbxExportRollout "ActorX 批量导出"
(
	-- copyright label
	label     Lbl1 "版本 1.07"
	label     Lbl2 "\xA9 2010-2022 Konstantin Nosov (Gildor)"
	hyperlink Lbl3 "http://www.gildor.org/" \
					address:"http://www.gildor.org/projects/unactorx" align:#center \
					color:black hovercolor:blue visitedcolor:black

	group "[ 常规 ]"
	(
		label    LblOutFormat      "保存格式:" across:2
		radiobuttons RadOutFormat labels:#("fbx", "ase", "max") default:g_outFormat align:#left columns:1
		checkbox ChkDefFbxSettings "使用默认 FBX 设置" checked:g_useDefaultFBXSettings
	)

	group "[ 网格体 ]"
	(
		label    Lbl10           "此工具将转换所有 PSK 网格体" align:#left
		label    Lbl11           "选择路径到指定的输出格式" align:#left
		label    Lbl12           ""
		edittext EdMeshPath      "PSK 文件路径" text:g_meshDir width:180 across:2
		button   BtnBrowseMesh   "选择"     align:#right height:16
		checkbox ChkMeshRecurse  "包含子文件夹" checked:g_meshRecurse
		checkbox ChkSmGroups     "平滑组" checked:g_fbxSmGroups
		checkbox ChkSmMesh       "使用 FBX 涡轮平滑" checked:g_fbxSmMesh
		button   BtnExportMeshes "导出网格"
	)

	group "[ 动画 ]"
	(
		label    Lbl20           "将所有动画从 PSA 转换为 FBX 格式"      align:#left
		label    Lbl21           "网格也应该被加载"     align:#left
		label    Lbl22           "如果没选择多镜头 FBX"     align:#left
		label    Lbl23           "则每个动画将生成一个 FBX 文件" align:#left
		label    Lbl24           ""                        align:#left
		checkbox ChkMultiTakeFbx "保存多镜头 FBX 文件" checked:g_fbxMultiTake
		button   BtnExportAnims  "导出动画"
	)

	on RadOutFormat      changed state do g_outFormat             = state
	on ChkDefFbxSettings changed state do g_useDefaultFBXSettings = state
	on ChkMultiTakeFbx   changed state do g_fbxMultiTake          = state
	on BtnExportAnims    pressed do ExportFbxAnim()
	on BtnExportMeshes   pressed do ExportFbxMeshes g_meshDir g_meshRecurse

	on EdMeshPath        changed val do g_meshDir = val
	on BtnBrowseMesh     pressed do
	(
		dir = getSavePath caption:"Directory for mesh lookup" initialDir:g_meshDir
		if dir != undefined then
		(
			g_meshDir       = dir
			EdMeshPath.text = dir
		)
	)
	on ChkMeshRecurse changed state do g_meshRecurse = state

	on ChkSmGroups changed state do g_fbxSmGroups = state
	on ChkSmMesh   changed state do g_fbxSmMesh   = state
)


if fbxExportFloater != undefined do closeRolloutFloater fbxExportFloater	-- close old window if visible
fbxExportFloater = newRolloutFloater "FBX Batch Export" 250 560 300 100 	-- create new window

addRollout fbxExportRollout fbxExportFloater
