require 'online_pay/alipay'
require 'online_pay/response'
require 'online_pay/sheng_fu_tong_pay'
require 'online_pay/sign'
require 'online_pay/version'
require 'online_pay/wx_pay'
require 'online_pay/wx_service'
require 'openssl'

module OnlinePay
  @wx_extra_rest_client_options = {}

  class << self
    # 微信支付相关参数
    # wx_key 指的是 paterner_key
    attr_accessor :wx_app_id, :wx_mch_id, :wx_key, :wx_app_secret, :wx_extra_rest_client_options, :wx_debug_mode
    attr_reader :wx_apiclient_cert, :wx_apiclient_key

    # 盛付通支付相关参数
    attr_accessor :sft_

    def set_apiclient_by_pkcs12(str, pass)
      pkc12 = OpenSSL::PKCS12.new(str, pass)

      @wx_apiclient_cert = pkc12.certificate
      @wx_apiclient_key = pkc12.key
    end

    def wx_apiclient_cert=(cert)
      @wx_apiclient_cert = OpenSSL::X509::Certificate.new(cert)
    end

    def wx_apiclient_key=(key)
      @wx_apiclient_key = OpenSSL::PKey::RSA.new(key)
    end

    def debug_mode?
      @wx_debug_mode || false
    end
  end

end
