module ApplicationHelper
  # A link is active on its own page and on any page nested under it, so
  # "Clients" stays highlighted on /clients/1/edit.
  def nav_link_to(name, path)
    active = current_page?(path) || request.path.start_with?("#{path}/")

    link_to name, path,
      class: class_names(
        "block rounded-md px-3 py-2 text-sm font-semibold",
        active ? "bg-navy-800 text-white" : "text-navy-300 hover:bg-navy-800 hover:text-white"
      ),
      aria: { current: ("page" if active) }
  end
end
