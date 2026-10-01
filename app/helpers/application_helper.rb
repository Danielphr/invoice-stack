module ApplicationHelper
  def nav_link_to(name, path)
    active = current_page?(path)

    link_to name, path,
      class: class_names(
        "block rounded-md px-3 py-2 text-sm font-semibold",
        active ? "bg-gray-800 text-white" : "text-gray-400 hover:bg-gray-800 hover:text-white"
      ),
      aria: { current: ("page" if active) }
  end
end
