module Currency
  ALL = {
    "USD" => { name: "US Dollar", symbol: "$", precision: 2 },
    "EUR" => { name: "Euro", symbol: "€", precision: 2 },
    "GBP" => { name: "British Pound", symbol: "£", precision: 2 },
    "JPY" => { name: "Japanese Yen", symbol: "¥", precision: 0 },
    "CNY" => { name: "Chinese Yuan", symbol: "¥", precision: 2 },
    "CHF" => { name: "Swiss Franc", symbol: "CHF", precision: 2 },
    "CAD" => { name: "Canadian Dollar", symbol: "$", precision: 2 },
    "AUD" => { name: "Australian Dollar", symbol: "$", precision: 2 },
    "MXN" => { name: "Mexican Peso", symbol: "$", precision: 2 },
    "BRL" => { name: "Brazilian Real", symbol: "R$", precision: 2 },
    "ARS" => { name: "Argentine Peso", symbol: "$", precision: 2 },
    "CLP" => { name: "Chilean Peso", symbol: "$", precision: 0 },
    "COP" => { name: "Colombian Peso", symbol: "$", precision: 2 },
    "UYU" => { name: "Uruguayan Peso", symbol: "$U", precision: 2 }
  }.freeze

  DEFAULT = "USD"

  def self.codes
    ALL.keys
  end

  def self.find(code)
    ALL.fetch(code)
  end
end
