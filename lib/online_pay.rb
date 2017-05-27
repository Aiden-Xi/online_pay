require 'online_pay/version'
require 'online_pay/wx_result'
require 'online_pay/wx_service'
require 'online_pay/wx_sign'
require 'online_pay/sheng_pay_result'
require 'online_pay/sheng_pay_service'
require 'online_pay/sheng_pay_sign'
require 'online_pay/alipay_result'
require 'online_pay/alipay_service'
require 'online_pay/alipay_sign'
require 'openssl'

module OnlinePay
  @wx_extra_rest_client_options = {}
  @debug_mode = true

  class << self
    # 公用参数
    attr_accessor :debug_mode

    # 微信支付相关参数
    # wx_key 指的是 paterner_key
    attr_accessor :wx_app_id, :wx_mch_id, :wx_key, :wx_app_secret, :wx_extra_rest_client_options
    attr_reader :wx_apiclient_cert, :wx_apiclient_key

    # 盛付通支付相关参数
    # 支付相关
    attr_accessor :shengpay_name, :shengpay_payment_version, :shengpay_exchange_rate_version, :shengpay_merchant_id,
                  :shengpay_merchant_key, :shengpay_charset, :shengpay_sign_type
    # 盛付通退款相关
    attr_accessor :shengrefund_sender_id, :shengrefund_version, :shengrefund_service_code
    # 盛付通订单查询
    attr_accessor :shengquery_service_code, :shengquery_version


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
      @debug_mode || false
    end
  end

end
