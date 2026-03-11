return {
    pipeworks = {
        string = {
            get_desc_from_name = function(node_name, mod_name)
                if mod_name == "pipeworks" then
                    return node_name:gsub("%{$", "")
                end
                return mod_name
            end
        }
    }
}
