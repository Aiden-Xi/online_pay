require 'rest_client'
require 'json'
require 'socket'
require 'online_pay/sheng_pay_sign'

module OnlinePay
  class ShengPayService
    # 支付url
    PaymentUrl = 'https://mas.shengpay.com/web-acquire-channel/cashier.htm?'
    PAYMENT_PAY_PARAMS = [:OrderNo, :OrderAmount, :OrderTime, :Currency, :PageUrl, :NotifyUrl, :realName, :idNo, :mobile]
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

    # 查询汇率url
    ExchangeRateUrl = 'https://tradeexprod.shengpay.com/fexchange-web/rest/merchant/queryExchangeRate?'
    EXCHANGE_RATE_PARAMS = [:foreignCurrency, :homeCurrency]
    def self.exchange_rate(params, options = {})
      params = {
          merchantId: params.delete(:merchantId) || OnlinePay.shengpay_merchant_id,
          charset: params.delete(:charset) || OnlinePay.shengpay_charset,
          version: params.delete(:version) || OnlinePay.shengpay_payment_version
      }.merge(params)

      check_required_options(params, EXCHANGE_RATE_PARAMS)

      sign = OnlinePay::ShengPaySign.rate_generate params

      # 查询汇率url
      exchange_rate_url = ExchangeRateUrl + params.merge(signMessage: sign).map { |k, v| "#{k}=#{v}" }.join('&')

      rest_client = RestClient.get exchange_rate_url

      JSON.parse(rest_client.body)['exSellPrice']
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

  end
end