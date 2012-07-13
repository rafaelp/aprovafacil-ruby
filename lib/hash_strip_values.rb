# -*- encoding : utf-8 -*-
class Hash
  def strip_values!

    self.each_value do |v|
      case v
        when String then v.strip!
        when Array  then v.each {|i| i.strip! }
        when Hash   then v.strip_values!
      end
    end

  end
end