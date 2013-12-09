# Weixin公众账号接口

本接口实现仅供参考。


2013-4-30:首次发布  
2013-5-10:接口修改为HTTPS模式工作，对于无法登录的情况增加sig和cert参数辅助登录冲，部分代码重构 
2013-12-09:修正8月份微信平台升级后的部分api地址修改的错误，补充官方API实现，测试修改为rspec实现
 

## Usage


微信的消息类型分为文本，图片，音频，视频，AppMsg，对应接口中的类型为1,2,3,4,10。AppMsg类型的消息是富文本，包含图片信息，一般通过管理台事先编辑好，发送时需要调用send_post函数。其它类型的消息调用send_message即可。图片，音频，视频消息发送前需要先通过avatar_upload上传，取得返回的fileId后，使用fileId作为send_message的参数。
