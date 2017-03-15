# frozen_string_literal: true
module OnlinePay
  class Response
    # 添加属性
    attr_accessor :code, :message, :messages

    #
    # 状态码
    #
    module Code
      # 添加模型常量国际化方法
      # include Dictionary::Module::I18n

      ################################################################################
      #
      # 20000 成功
      #
      ################################################################################

      SUCCESS = '200'

      ################################################################################
      #
      # 3xxxx 数据相关
      #
      ################################################################################

      # 用户绑定第三方账户

      # 第三方账户已绑定其它用户
      PROVIDER_BIND_ANOTHER_USER = '301'

      ################################################################################
      #
      # 4xxxx 业务相关
      #
      ################################################################################

      # 非法请求
      INVALID_REQUEST = '401'

      # 终端密钥错误
      INVALID_TERMINAL_SESSION_KEY = '402'

      # 用户密钥错误
      INVALID_USER_SESSION_KEY = '403'

      # 超出请求限制数
      EXCEED_REQUEST_LIMIT = '404'

      # 访问令牌过期
      ACCESS_TOKEN_EXPIRED = '405'

      ################################################################################
      #
      # 5xxxx 系统相关
      #
      ################################################################################

      # 未知错误（通常在捕捉异常后使用）
      ERROR = '500'
    end

    #
    # 实例对象
    #
    # @param code [Code] 编码
    # @param message [String] 返回信息
    # @param messages [Array] 可能的错误信息
    #
    # @return [Response] 返回实例化的对象
    #
    def initialize(code = Code::SUCCESS, message = '请求成功', messages = [])
      @code = code
      @message = message
      @messages = messages
    end

    def method_missing(method_id, *arguments, &block)
      method_message = *arguments.join
      if (method_id.to_s =~ /^raise_[\w]+/) == 0
        error_type = method_id.to_s.split('raise_')[1].upcase!
        @code = "Response::Code::#{error_type}".constantize
        @message = method_message
        raise StandardError.new(method_message)
      else
        super
      end
    end

    def self.rescue(catch_block = nil)
      response = self.new
      Rails.logger.info "response为#{response.to_json}"
      begin
        yield(response)
      rescue => e
        if (e.class != StandardError && ENV['RAILS_ENV'] == 'development')
          throw e
        end

        catch_block.call if catch_block.present?

        if response.code == Code::SUCCESS
          response.code = Code::ERROR

          response.message = e.message

          # 测试环境报错
          # 正式环境提示错误信息
          # Rails.env.production? ? (response.message = '抱歉数据请求失败，请稍后再试') : (response.message = e.message)
        end
      end

      response
    end

    #
    # 生成一个错误异常
    #
    # @example
    #   Response.error
    #     => #<Response:0x007feb7b049638 @code="50000", @message="未知异常", @messages=[]>
    #
    # @return [Response] 响应对象
    #
    def self.error
      response = self.new
      response.code = Code::ERROR
      response.message = '未知异常'

      response
    end

  end
end

