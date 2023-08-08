安装方法：

找一空白U盘，设置U盘的分区方式为gpt。

以下有两种使用方案：

1、将U盘格式化为一个完整的VFAT格式分区，将boot、EFI、images和LABEL都复制到该分区即可。

2、将U盘分两个区，第一个分区格式化为VFAT格式，将第二个分区格式化为xfs、ext3、ext4等Linux下常用根分区的格式，将boot和EFI复制到第一分区中，将images和LABEL复制到第二分区，并在第二分区创建一个“.userdata”的目录。

第一种方案类似LiveCD，系统使用中创建的数据将在关机或重启后消失；第二种方案数据将保存在.userdata目录中，若不创建该目录将和第一种方案一样。

启动后默认用户(loongarch)的密码为"loongson"。
