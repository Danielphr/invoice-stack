# Data every environment needs goes here. Demo data is for local development only:
# db:prepare also seeds a newly created production database.
load Rails.root.join("db/seeds/development.rb") if Rails.env.development?
