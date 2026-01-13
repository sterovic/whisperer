module DashboardHelper
  MASKS = {
    1 => "mask-squircle",
    2 => "mask-heart",
    3 => "mask-hexagon",
    4 => "mask-hexagon-2",
    5 => "mask-decagon",
    6 => "mask-pentagon",
    7 => "mask-diamond",
    8 => "mask-square",
    9 => "mask-circle",
    10 => "mask-star",
    11 => "mask-triangle",
    12 => "mask-triangle-2",
    13 => "mask-triangle-3",
    14 => "mask-triangle-4"
  }.freeze

  COLORS = {
    1 => "bg-red-500",
    2 => "bg-orange-500",
    3 => "bg-amber-500",
    4 => "bg-yellow-500",
    5 => "bg-green-500",
    6 => "bg-emerald-500",
    7 => "bg-teal-500",
    8 => "bg-cyan-500",
    9 => "bg-sky-500",
    10 => "bg-blue-500",
    11 => "bg-indigo-500",
    12 => "bg-violet-500",
    13 => "bg-purple-500",
    14 => "bg-fuchsia-500",
    15 => "bg-pink-500",
    16 => "bg-rose-500",
    17 => "bg-slate-500",
    18 => "bg-gray-500",
    19 => "bg-zinc-500",
    20 => "bg-neutral-500",
    21 => "bg-stone-500",
  }.freeze

  BG_COLORS = {
    1 => "bg-red-500/20",
    2 => "bg-orange-500/20",
    3 => "bg-amber-500/20",
    4 => "bg-yellow-500/20",
    5 => "bg-green-500/20",
    6 => "bg-emerald-500/20",
    7 => "bg-teal-500/20",
    8 => "bg-cyan-500/20",
    9 => "bg-sky-500/20",
    10 => "bg-blue-500/20",
    11 => "bg-indigo-500/20",
    12 => "bg-violet-500/20",
    13 => "bg-purple-500/20",
    14 => "bg-fuchsia-500/20",
    15 => "bg-pink-500/20",
    16 => "bg-rose-500/20",
    17 => "bg-slate-500/20",
    18 => "bg-gray-500/20",
    19 => "bg-zinc-500/20",
    20 => "bg-neutral-500/20",
    21 => "bg-stone-500/20",
  }.freeze

  def project_avatar(project_id)
    rand = rand(1..21)
    tag.div class: "#{project_bg_color(rand)} rounded-box flex size-8 items-center justify-center" do
      tag.div class: "mask #{project_mask(rand)} #{project_color(rand)} size-5"
    end
  end

  def user_initials(name, last_name)
    name[0] + last_name[0]
  end

  private

  def project_mask(project_id)
    MASKS[project_id % MASKS.length + 1]
  end

  def project_color(project_id)
    COLORS[project_id % COLORS.length + 1]
  end

  def project_bg_color(project_id)
    BG_COLORS[project_id % BG_COLORS.length + 1]
  end
end