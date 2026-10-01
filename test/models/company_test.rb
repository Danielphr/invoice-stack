require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  test "onboarding is incomplete without a name" do
    company = Company.new

    assert_not company.onboarding_complete?
  end

  test "onboarding is incomplete with a blank name" do
    company = Company.new(name: "   ")

    assert_not company.onboarding_complete?
  end

  test "onboarding is complete with a name" do
    company = Company.new(name: "Acme Inc.")

    assert company.onboarding_complete?
  end

  test "name is required on update" do
    company = companies(:one)
    company.name = ""

    assert_not company.valid?
    assert_includes company.errors[:name], "can't be blank"
  end
end
