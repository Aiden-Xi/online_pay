require 'rest_client'
require 'json'
require 'cgi'
require 'socket'
require 'securerandom'
require 'active_support/core_ext/hash/conversions'
require 'online_pay/wx_result'

module OnlinePay
  class WxService

    # 微信支付相关订单统一接口
    # GATEWAY_URL = 'https://api.mch.weixin.qq.com'

    def self.generate_authorize_url(redirect_uri, state = nil)
      state ||= SecureRandom.hex 16
      "https://open.weixin.qq.com/connect/oauth2/authorize?appid=#{OnlinePay.wx_app_id}&redirect_uri=#{CGI::escape redirect_uri}&response_type=code&scope=snsapi_base&state=#{state}"
    end

    def self.authenticate(authorization_code, options = {})
      options = OnlinePay.extra_rest_client_options.merge(options)
      url = "https://api.weixin.qq.com/sns/oauth2/access_token?appid=#{OnlinePay.wx_app_id}&secret=#{OnlinePay.wx_app_secret}&code=#{authorization_code}&grant_type=authorization_code"

      ::JSON.parse(RestClient::Request.execute(
          {
              method: :get,
              url: url
          }.merge(options)
      ), quirks_mode: true)
    end

    def self.authenticate_from_weapp(js_code, options = {})
      options = OnlinePay.extra_rest_client_options.merge(options)
      url = "https://api.weixin.qq.com/sns/jscode2session?appid=#{OnlinePay.wx_app_id}&secret=#{OnlinePay.wx_app_secret}&js_code=#{js_code}&grant_type=authorization_code"

      ::JSON.parse(RestClient::Request.execute(
          {
              method: :get,
              url: url
          }.merge(options)
      ), quirks_mode: true)
    end

    #
    # 扫码支付 - 统一下单接口：https://api.mch.weixin.qq.com/pay/unifiedorder
    # 不需要证书
    INVOKE_UNIFIEDORDER_REQUIRED_FIELDS = [:body, :out_trade_no, :total_fee, :spbill_create_ip, :notify_url, :trade_type].map!(&:freeze).freeze

    def self.invoke_unifiedorder(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          key: options.delete(:key) || OnlinePay.wx_key,
          nonce_str: SecureRandom.hex,
          spbill_create_ip: ::Socket::getaddrinfo(Socket.gethostname, "echo", Socket::AF_INET)[0][3]
      }.merge(params)

      check_required_options(params, INVOKE_UNIFIEDORDER_REQUIRED_FIELDS)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/pay/unifiedorder", make_payload(params), options)))

      yield r if block_given?

      r
    end

    # TODO: - 撤销
    # if true
    # 订单关闭接口 - URL：https://api.mch.weixin.qq.com/pay/closeorder
    # 不需要证书
    INVOKE_CLOSEORDER_REQUIRED_FIELDS = [:out_trade_no].map!(&:freeze).freeze

    def self.invoke_closeorder(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          key: options.delete(:key) || OnlinePay.wx_key,
          nonce_str: SecureRandom.hex
      }.merge(params)

      check_required_options(params, INVOKE_CLOSEORDER_REQUIRED_FIELDS)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/pay/closeorder", make_payload(params), options)))

      yield r if block_given?

      r
    end

    GENERATE_APP_PAY_REQ_REQUIRED_FIELDS = [:prepayid, :noncestr].map!(&:freeze).freeze

    def self.generate_app_pay_req(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          partnerid: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          key: options.delete(:key) || OnlinePay.wx_key,
          package: 'Sign=OnlinePay',
          timestamp: Time.now.to_i.to_s
      }.merge(params)

      check_required_options(params, GENERATE_APP_PAY_REQ_REQUIRED_FIELDS)

      params[:sign] = OnlinePay::WxSign.generate(params)

      params
    end

    GENERATE_JS_PAY_REQ_REQUIRED_FIELDS = [:prepayid, :noncestr].map!(&:freeze).freeze

    def self.generate_js_pay_req(params, options = {})
      check_required_options(params, GENERATE_JS_PAY_REQ_REQUIRED_FIELDS)

      params = {
          appId: options.delete(:appid) || OnlinePay.wx_app_id,
          package: "prepay_id=#{params.delete(:prepayid)}",
          key: options.delete(:key) || OnlinePay.wx_key,
          nonceStr: params.delete(:noncestr),
          timeStamp: Time.now.to_i.to_s,
          signType: 'MD5'
      }.merge(params)

      params[:paySign] = OnlinePay::WxSign.generate(params)
      params
    end

    # 申请退款接口 - URL： https://api.mch.weixin.qq.com/secapi/pay/refund
    # 需要证书（证书使用详情） - 具体使用URL： https://pay.weixin.qq.com/wiki/doc/api/native.php?chapter=4_3
    # out_trade_no 和 transaction_id 是二选一(必填)
    INVOKE_REFUND_REQUIRED_FIELDS = [:out_refund_no, :total_fee, :refund_fee, :op_user_id].map!(&:freeze).freeze

    def self.invoke_refund(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex,
      }.merge(params)

      params[:op_user_id] ||= params[:mch_id]

      check_required_options(params, INVOKE_REFUND_REQUIRED_FIELDS)
      warn("OnlinePay Warn: missing required option: out_trade_no or transaction_id must have one") if ([:out_trade_no, :transaction_id] & params.keys) == []

      options = {
          ssl_client_cert: options.delete(:apiclient_cert) || OnlinePay.wx_apiclient_cert,
          ssl_client_key: options.delete(:apiclient_key) || OnlinePay.wx_apiclient_key,
          verify_ssl: OpenSSL::SSL::VERIFY_NONE
      }.merge(options)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/secapi/pay/refund", make_payload(params), options)))

      yield r if block_given?

      r
    end

    # 退款查询接口 - URL： https://api.mch.weixin.qq.com/pay/refundquery
    # 不需要证书
    REFUND_QUERY_REQUIRED_FIELDS = [:out_trade_no].map!(&:freeze).freeze

    def self.refund_query(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex
      }.merge(params)

      check_required_options(params, ORDER_QUERY_REQUIRED_FIELDS)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/pay/refundquery", make_payload(params), options)))

      yield r if block_given?

      r
    end

    # 企业付款 - URL： https://api.mch.weixin.qq.com/mmpaymkttransfers/promotion/transfers
    # 需要使用证书
    INVOKE_TRANSFER_REQUIRED_FIELDS = [:partner_trade_no, :openid, :check_name, :amount, :desc, :spbill_create_ip].map!(&:freeze).freeze

    def self.invoke_transfer(params, options = {})
      params = {
          mch_appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mchid: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex
      }.merge(params)

      check_required_options(params, INVOKE_TRANSFER_REQUIRED_FIELDS)

      options = {
          ssl_client_cert: options.delete(:apiclient_cert) || OnlinePay.wx_apiclient_cert,
          ssl_client_key: options.delete(:apiclient_key) || OnlinePay.wx_apiclient_key,
          verify_ssl: OpenSSL::SSL::VERIFY_NONE
      }.merge(options)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/mmpaymkttransfers/promotion/transfers", make_payload(params), options)))

      yield r if block_given?

      r
    end

    # 查询企业付款 - URL： https://api.mch.weixin.qq.com/mmpaymkttransfers/gettransferinfo
    # 需要使用证书
    GETTRANSFERINFO_FIELDS = [:partner_trade_no].map!(&:freeze).freeze

    def self.gettransferinfo(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex
      }.merge(params)

      check_required_options(params, GETTRANSFERINFO_FIELDS)

      options = {
          ssl_client_cert: options.delete(:apiclient_cert) || OnlinePay.wx_apiclient_cert,
          ssl_client_key: options.delete(:apiclient_key) || OnlinePay.wx_apiclient_key,
          verify_ssl: OpenSSL::SSL::VERIFY_NONE
      }.merge(options)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/mmpaymkttransfers/gettransferinfo", make_payload(params), options)))

      yield r if block_given?

      r
    end

    # 撤销订单 - URL： https://api.mch.weixin.qq.com/secapi/pay/reverse
    # 需要使用证书
    INVOKE_REVERSE_REQUIRED_FIELDS = [:out_trade_no].map!(&:freeze).freeze

    def self.invoke_reverse(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex
      }.merge(params)

      check_required_options(params, INVOKE_REVERSE_REQUIRED_FIELDS)

      options = {
          ssl_client_cert: options.delete(:apiclient_cert) || OnlinePay.wx_apiclient_cert,
          ssl_client_key: options.delete(:apiclient_key) || OnlinePay.wx_apiclient_key,
          verify_ssl: OpenSSL::SSL::VERIFY_NONE
      }.merge(options)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/secapi/pay/reverse", make_payload(params), options)))

      yield r if block_given?

      r
    end

    # 微信刷卡支付 - URL： https://api.mch.weixin.qq.com/pay/micropay
    # 不需要证书
    INVOKE_MICROPAY_REQUIRED_FIELDS = [:body, :out_trade_no, :total_fee, :spbill_create_ip, :auth_code].map!(&:freeze).freeze

    def self.invoke_micropay(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex
      }.merge(params)

      check_required_options(params, INVOKE_MICROPAY_REQUIRED_FIELDS)

      options = {
          ssl_client_cert: options.delete(:apiclient_cert) || OnlinePay.wx_apiclient_cert,
          ssl_client_key: options.delete(:apiclient_key) || OnlinePay.wx_apiclient_key,
          verify_ssl: OpenSSL::SSL::VERIFY_NONE
      }.merge(options)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/pay/micropay", make_payload(params), options)))

      yield r if block_given?

      r
    end

    #
    # 订单查询接口， URL：https://api.mch.weixin.qq.com/pay/orderquery
    # 不需要证书
    ORDER_QUERY_REQUIRED_FIELDS = [:out_trade_no].map!(&:freeze).freeze

    def self.order_query(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex
      }.merge(params)


      check_required_options(params, ORDER_QUERY_REQUIRED_FIELDS)
      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/pay/orderquery", make_payload(params), options)))

      yield r if block_given?

      r
    end

    # 下载对账单接口 - URL： https://api.mch.weixin.qq.com/pay/downloadbill
    # 不需要证书
    # FIXME: 只能下载三个月以内的对账单
    DOWNLOAD_BILL_REQUIRED_FIELDS = [:bill_date, :bill_type].map!(&:freeze).freeze

    def self.download_bill(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex,
      }.merge(params)

      check_required_options(params, DOWNLOAD_BILL_REQUIRED_FIELDS)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/pay/downloadbill", make_payload(params), options)))

      yield r if block_given?

      r
    end

    # 获取汇率换算 - URL: https://api.mch.weixin.qq.com/pay/queryexchagerate
    def self.get_exchange_rate(params, options = {})
      params = {
          appid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
      }.merge(params)

      check_required_options(params, DOWNLOAD_BILL_REQUIRED_FIELDS)

      r = Hash.from_xml(invoke_remote("#{gateway_url}/pay/queryexchagerate", make_payload(params), options)).dig('xml')

      yield r if block_given?

      # FIXME: 20200326 当前时间，返回的数据结构，需要对rate做优化, 这里返回的数据长度有问题：
      # {
      #     "return_code" => "SUCCESS",
      #     "return_msg" => "OK",
      #     "appid" => "wxfe25f02f90292ae0",
      #     "mch_id" => "1453375002",
      #     "fee_type" => "AUD",
      #     "rate_time" => "20200321",
      #     "rate" => "412550100",
      #     "sign" => "1B407EB855C912139E22563614E4042C"
      # }
      if r['return_code'] == OnlinePay::WxResult::SUCCESS && r['rate'].length == 9
        r['rate'] = ('%.4f' % (r['rate'][0..4].to_f / 10000))
      end

      return r
    end

    # 发送裂变红包 - URL：https://api.mch.weixin.qq.com/mmpaymkttransfers/sendgroupredpack
    # 需要证书
    def self.sendgroupredpack(params, options = {})
      params = {
          wxappid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex
      }.merge(params)

      #check_required_options(params, INVOKE_MICROPAY_REQUIRED_FIELDS)

      options = {
          ssl_client_cert: options.delete(:apiclient_cert) || OnlinePay.wx_apiclient_cert,
          ssl_client_key: options.delete(:apiclient_key) || OnlinePay.wx_apiclient_key,
          verify_ssl: OpenSSL::SSL::VERIFY_NONE
      }.merge(options)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/mmpaymkttransfers/sendgroupredpack", make_payload(params), options)))

      yield r if block_given?

      r
    end

    # 发送普通红包 - URL： https://api.mch.weixin.qq.com/mmpaymkttransfers/sendredpack
    # 需要证书
    def self.sendredpack(params, options = {})
      params = {
          wxappid: options.delete(:appid) || OnlinePay.wx_app_id,
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex
      }.merge(params)

      #check_required_options(params, INVOKE_MICROPAY_REQUIRED_FIELDS)

      options = {
          ssl_client_cert: options.delete(:apiclient_cert) || OnlinePay.wx_apiclient_cert,
          ssl_client_key: options.delete(:apiclient_key) || OnlinePay.wx_apiclient_key,
          verify_ssl: OpenSSL::SSL::VERIFY_NONE
      }.merge(options)

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/mmpaymkttransfers/sendredpack", make_payload(params), options)))

      yield r if block_given?

      r
    end

    # end
    # TODO: - 撤销

    # 获取 sandbox_new 验签秘钥API - URL: https://api.mch.weixin.qq.com/sandboxnew/pay/getsignkey
    # 不需要证书
    def self.get_sign_key(sign, options = {})
      params = {
          mch_id: options.delete(:mch_id) || OnlinePay.wx_mch_id,
          nonce_str: SecureRandom.hex,
          sign: sign
      }

      r = OnlinePay::WxResult.new(Hash.from_xml(invoke_remote("#{gateway_url}/pay/getsignkey", sandbox_new_make_payload(params), options)))

      yield r if block_given?

      r
    end

    class << self
      private

      def gateway_url
        OnlinePay.sandbox_new_mode? ? 'https://api.mch.weixin.qq.com/sandboxnew'.freeze : 'https://api.mch.weixin.qq.com'.freeze
      end

      def check_required_options(options, names)
        return unless OnlinePay.debug_mode?
        names.each do |name|
          warn("OnlinePay Warn: missing required option: #{name}") unless options.has_key?(name)
        end
      end

      def make_payload(params)
        sign = OnlinePay::WxSign.generate(params)
        if OnlinePay.sandbox_new_mode?
          sandbox_new_result = get_sign_key(sign)
          params[:key] = sandbox_new_result.fetch('sandbox_signkey', nil)
          sign = OnlinePay::WxSign.generate(params)
        end
        params.delete(:key) if params[:key]
        "<xml>#{params.map { |k, v| "<#{k}>#{v}</#{k}>" }.join}<sign>#{sign}</sign></xml>"
      end

      def sandbox_new_make_payload(params)
        params.delete(:key) if params[:key]
        "<xml>#{params.map { |k, v| "<#{k}>#{v}</#{k}>" }.join}</xml>"
      end

      def invoke_remote(url, payload, options = {})
        options = OnlinePay.wx_extra_rest_client_options.merge(options)
        RestClient::Request.execute(
            {
                method: :post,
                url: url,
                payload: payload,
                headers: { content_type: 'application/xml' }
            }.merge(options)
        )
      end
    end

  end
end