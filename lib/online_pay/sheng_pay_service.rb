require 'rest_client'
require 'json'
require 'socket'
require 'online_pay/sheng_pay_sign'

module OnlinePay
  class ShengPayService
    # 支付url
    PaymentUrl = 'https://mas.shengpay.com/web-acquire-channel/cashier.htm?'
    PAYMENT_PAY_PARAMS = [:OrderNo, :OrderAmount, :OrderTime, :Currency, :PageUrl, :NotifyUrl, :realName, :idNo, :mobile].map!(&:freeze).freeze
    def self.shengpay(params, options = {})
      params = {
          Name: options.delete(:Name) || OnlinePay.shengpay_name,
          Version: options.delete(:Version) || OnlinePay.shengpay_payment_version,
          Charset: options.delete(:Charset) || OnlinePay.shengpay_charset,
          MsgSender: options.delete(:MsgSender) || OnlinePay.shengpay_merchant_id,
          SignType: options.delete(:SignType) || OnlinePay.shengpay_sign_type,
          BuyerIp: Socket::getaddrinfo(Socket.gethostname,"echo",Socket::AF_INET)[0][3]
      }.merge(params)

      check_required_options(params, PAYMENT_PAY_PARAMS)

      sign = OnlinePay::ShengPaySign.generate params

      payment_url = get_payment_url(params, sign)

      payment_url
    end

    # 退款申请
    RefundUrl = 'https://mas.shengpay.com/api-acquire-channel/services/refundService?'
    REFUND_PARAMS = [:SendTime, :RefundOrderNo, :OriginalOrderNo, :RefundAmount, :NotifyURL, :RefundRoute]
    def self.sheng_refund(params, options = {})
      params = {
          ServiceCode: params.delete(:ServiceCode) || OnlinePay.shengrefund_service_code,
          Version: options.delete(:Version) || OnlinePay.shengrefund_payment_version,
          Charset: options.delete(:Charset) || OnlinePay.shengpay_charset,
          SenderId: options.delete(:SenderId) || OnlinePay.shengpay_merchant_id,
          merchantNo: params.delete(:merchantId) || OnlinePay.shengpay_merchant_id,
          SignType: options.delete(:SignType) || OnlinePay.shengpay_sign_type
      }.merge(params)

      check_required_options(params, REFUND_PARAMS)

      sign = OnlinePay::ShengPaySign.generate params

      refund_url = get_refund_url params, sign

      refund_url
    end

    # 订单查询
    QueryUrl = 'https://mas.shengpay.com/api-acquire-channel/services/queryOrderService?'
    QUERY_PARAMS = [:SendTime, :OrderNo, :TransNo]
    def self.query_order(params, options = {})
      params = {
          ServiceCode: params.delete(:ServiceCode) || OnlinePay.shengquery_service_code,
          Version: options.delete(:Version) || OnlinePay.shengquery_version,
          Charset: options.delete(:Charset) || OnlinePay.shengpay_charset,
          SenderId: options.delete(:SenderId) || OnlinePay.shengpay_merchant_id,
          merchantNo: params.delete(:merchantId) || OnlinePay.shengpay_merchant_id,
          SignType: options.delete(:SignType) || OnlinePay.shengpay_sign_type
      }.merge(params)

      check_required_options(params, QUERY_PARAMS)

      sign = OnlinePay::ShengPaySign.generate params

      query_url = get_query_url params, sign

      query_url
    end

    # 查询汇率url
    ExchangeRateUrl = 'https://tradeexprod.shengpay.com/fexchange-web/rest/merchant/queryExchangeRate?'
    EXCHANGE_RATE_PARAMS = [:foreignCurrency, :homeCurrency].map!(&:freeze).freeze
    def self.exchange_rate(params, options = {})
      params = {
          merchantId: params.delete(:merchantId) || OnlinePay.shengpay_merchant_id,
          charset: params.delete(:charset) || OnlinePay.shengpay_charset,
          version: params.delete(:version) || OnlinePay.shengpay_exchange_rate_version
      }.merge(params)

      check_required_options(params, EXCHANGE_RATE_PARAMS)

      sign = OnlinePay::ShengPaySign.rate_generate params

      # 查询汇率url
      exchange_rate_url = ExchangeRateUrl + params.merge(signMessage: sign).map { |k, v| "#{k}=#{v}" }.join('&')

      rest_client = RestClient.get exchange_rate_url

      JSON.parse(rest_client.body)
    end

    # 获取防钓鱼时间戳
    SendTimeUrl = 'https://api.shengpay.com/mas/v1/timestamp?'
    SEND_TIME_PARAMS = [:merchantNo].map!(&:freeze).freeze
    def self.get_send_time(params, options = {})
      params = {
          merchantNo: params.delete(:merchantId) || OnlinePay.shengpay_merchant_id
      }.merge(params)

      check_required_options(params, SEND_TIME_PARAMS)

      send_time_url = SendTimeUrl + params.map { |k, v| "#{k}=#{v}" }.join('&')

      rest_client = RestClient.get send_time_url

      JSON.parse(rest_client)
    end


    private
    # 检查必须参数
    def self.check_required_options(options, names)
      return unless OnlinePay.debug_mode?
      names.each do |name|
        warn("OnlinePay Warn: missing required option: #{name}") unless options.has_key?(name)
      end
    end

    # 生成支付的URL
    def self.get_payment_url(params, sign)
      PaymentUrl + params.merge(SignMsg: sign).map { |k, v| "#{k}=#{v}" }.join('&')
    end

    # 生成退款的URL
    def self.get_refund_url(params, sign)
      RefundUrl + params.merge(SignMsg: sign).map { |k, v| "#{k}=#{v}" }.join('&')
    end

    # 生成查询URL
    def self.get_query_url(params, sign)
      QueryUrl + params.merge(SignMsg: sign).map { |k, v| "#{k}=#{v}" }.join('&')
    end

  end
end