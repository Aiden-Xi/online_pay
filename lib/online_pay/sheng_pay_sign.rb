require 'digest/md5'

module OnlinePay
  class ShengPaySign
    def self.generate(params)
      payment_values = params.values.compact
      sign = Digest::MD5.hexdigest(payment_values.join('|') + '|' + OnlinePay.shengpay_merchant_key).upcase
      puts "生成的签名sign = #{sign}"
      sign
    end

    def self.verify?(params)
      params = params.dup
      sign = params.delete('SignMsg') || params.delete(:SignMsg)

      generate(params) == sign
    end

    def self.rate_generate(params)
      key = params.delete(:key)

      query = params.sort.map do |k, v|
        "#{k}=#{v}" if v.to_s != ''
      end.compact.join('')

      Digest::MD5.hexdigest(query + (key || OnlinePay.shengpay_merchant_key)).upcase
    end
  end
end