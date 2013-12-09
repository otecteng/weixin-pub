# encoding: utf-8
require "wx_api"
describe WeixinPublic::WeixinAPIClient do
  subject {
    client = WeixinPublic::WeixinAPIClient.new("wxea2ce7f47689a346","3a5c43e567e95d022b50d9e09dc81577") 
  }

  it "get info" do
    p "-----settings----- "
    p subject.api_get_user_list
  end


  it "set menu" do
    p "-----set menu----- "
	menu = {
    	"button"=>
    	[
	     	{"type" => "click","name"=> "今日歌曲","key"=> "V1001_TODAY_MUSIC"},
	      	{"type" => "click","name"=> "歌手简介","key"=> "V1001_TODAY_SINGER"},
	      	{"name" => "菜单",
	           "sub_button"=>[
	           		{"type"=> "view","name" => "搜索","url"=> "http://g.cn/"},
	            	{"type"=> "view","name" => "视频","url"=> "http://v.qq.com/"},
	            	{"type"=> "click","name"=> "赞一下我们","key"=> "V1001_GOOD"}
	            ]
	        }
   		]
 	}

    p subject.api_set_menu(menu)
  end  

  it "get menu" do
    p "-----get menu----- "
    p subject.api_get_menu
  end

  it  "send message" do 
  	p "-----send message----- "
  	p subject.api_get_menu
  end
end