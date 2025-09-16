# 1-修复了导出psa路径报错的问题. 1
# 2-支持了一键导出文件夹下的psa 1
# 3-使用方法： 1
		将ActorXImporter.ms拖入3ds Max即可

# 4-操作说明： 1
    1.Mesh合并：一起导入角色的模型psk文件自动合并
    2.导出FBX文件：点击导入PSA目标文件夹按钮，选中目标角色PSA资源的根目录，结构如下:
    	-0xx_XXX
    		--animation
    			---attack
    			---basic
    			---etc
    			---specialskill
    			---superarts 
    将在attack/.../superarts 中生成FBX文件夹，存放生成的FBX文件
    3.命名
    	prefix.txt - 给生成的fbx文件加个前缀如SM6_Ken_，便于区分
