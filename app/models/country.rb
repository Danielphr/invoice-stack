module Country
  NAMES = {
    "AR" => "Argentina",
    "AU" => "Australia",
    "AT" => "Austria",
    "BE" => "Belgium",
    "BR" => "Brazil",
    "CA" => "Canada",
    "CL" => "Chile",
    "CN" => "China",
    "CO" => "Colombia",
    "DK" => "Denmark",
    "FR" => "France",
    "DE" => "Germany",
    "IN" => "India",
    "ID" => "Indonesia",
    "IL" => "Israel",
    "IT" => "Italy",
    "JP" => "Japan",
    "MX" => "Mexico",
    "NL" => "Netherlands",
    "NO" => "Norway",
    "PE" => "Peru",
    "PL" => "Poland",
    "PT" => "Portugal",
    "RU" => "Russia",
    "SA" => "Saudi Arabia",
    "SG" => "Singapore",
    "ZA" => "South Africa",
    "KR" => "South Korea",
    "ES" => "Spain",
    "SE" => "Sweden",
    "CH" => "Switzerland",
    "TR" => "Turkey",
    "AE" => "United Arab Emirates",
    "GB" => "United Kingdom",
    "US" => "United States",
    "UY" => "Uruguay"
  }.freeze

  def self.codes
    NAMES.keys
  end

  def self.name_for(code)
    NAMES[code]
  end
end
