module DashboardHelper
    def percentage(value, total)
        return "0.0%" if total.to_i.zero?

        result = value.to_f / total.to_f*100

        number_to_percentage(
            result,
            precision: 1
        )
    end
end
