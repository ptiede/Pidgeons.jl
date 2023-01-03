

round_folder(round::Int, parent_folder = exec_folder()) = exec_folder / "round=$round"

function symlink_completed_rounds(round_folder)
    parent_folder = dirname(round_folder)
    folder_name = basename(round_folder)
    round_index = parse(Int, last(split(folder_name)))
    for r = 1:(round_index - 1)
        target = round_folder(r, parent_folder)
        link = round_folder(r)
        symlink(target, link, dir_target = true)
    end
end

function load_immutables(round_folder)
    parent_folder = dirname(round_folder)
    deserialize_immutables(parent_folder / "immutables.jls")
end