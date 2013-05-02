# Weixin公众账号接口

根据Weixin公众账号Web管理控制台协议工作，目前本版本可正常工作(2013-4-30)，腾讯已经将web控制台的浏览器强制为HTTPS工作，本接口实现仅供参考。


## Demo
```ruby
require 'weixin_public.rb'
client = WeixinPublicClient::WeixinPubClient.new('x@gmail.com','123')
```

群发文本消息：
```ruby
client.get_fans.each do |fan|
  client.send_message("hello","1",fan.fakeId)
end
```

获取指定用户的对话信息：
```ruby
fakeId = '1234'
msgs = client.get_messages(fakeId)
msgs.each {|m| p "#{m.dateTime} << #{m.content}"} 
```

图片，音频：
```ruby
fileId = client.avatar_upload('pix.jpg')
client.send_message(fileId,"2",fan.fakeId)
```
## Usage


微信的消息类型分为文本，图片，音频，视频，AppMsg，对应接口中的类型为1,2,3,4,10。AppMsg类型的消息是富文本，包含图片信息，一般通过管理台事先编辑好，发送时需要调用send_post函数。其它类型的消息调用send_message即可。图片，音频，视频消息发送前需要先通过avatar_upload上传，取得返回的fileId后，使用fileId作为send_message的参数。
