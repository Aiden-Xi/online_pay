module OnlinePay
  class WxResult < ::Hash
    SUCCESS = 'SUCCESS'.freeze

    def initialize(result)
      super nil

      self[:raw] = result

      if result['xml'].class == Hash
        result['xml'].each_pair do |k, v|
          self[k] = v
        end
      end
    end
    
    def success?
      self['return_code'] == SUCCESS && self['result_code'] == SUCCESS
    end
  end
end