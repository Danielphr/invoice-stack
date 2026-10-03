class Companies::LogosController < ApplicationController
  def destroy
    Current.user.company.logo.purge
    redirect_to edit_company_path, notice: "Logo removed.", status: :see_other
  end
end
