require "wx_https"

describe WeixinPublic::WeixinPubClient do
  subject {
    client = WeixinPublic::WeixinPubClient.new("abc@163.com","abc") 
    client.login
    client
  }

  it "get info" do
    p "-----settings----- "
    p subject.get_settings
  end

  it "read fans and messages" do
    p "----read messages----"
    msg = subject.get_messages
    p msg
    p "-----read fans----- "
    fans = subject.get_fans
    p fans
    if fans.length > 0
    	fan = fans.first 
    	p "-----talk info----- "
    	p subject.get_talk(fan.fake_id)
    end
  end
  
  it "get picture files" do
  	p subject.get_file_lst(2)
  end

  it "get and set dev status" do
    p subject.get_dev_status
    subject.switch_dev_mode
  end

  it "send single msg to fan" do
    fans = subject.get_fans
    if fans.length > 0
      p fans.last.fake_id
      subject.send_message("your sister!",fans.last.fake_id)
    end
  end

end