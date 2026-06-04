# CUSTOM KITTY COMMAND
# This basically just adds a file browser pane to kitty
# This cannot run by itself, it must be sourced from .zshrc

autoload -Uz add-zsh-hook

_kitty_files_publish_cwd() {
    [[ -z "${KITTY_WINDOW_ID:-}" ]] && return

    local cwd_state_dir="${XDG_RUNTIME_DIR:-/tmp}/kitty-cwd"
    mkdir -p "$cwd_state_dir"

    print -r -- "$PWD" > "$cwd_state_dir/$KITTY_WINDOW_ID"
}

add-zsh-hook -d chpwd _kitty_files_publish_cwd 2>/dev/null
add-zsh-hook -d precmd _kitty_files_publish_cwd 2>/dev/null
add-zsh-hook chpwd _kitty_files_publish_cwd
add-zsh-hook precmd _kitty_files_publish_cwd

files() {
    [[ -z "${KITTY_WINDOW_ID:-}" ]] && {
        echo "Run inside kitty"
        return 1
    }

    local caller_window_id="$KITTY_WINDOW_ID"
    local watch_window_id="$KITTY_WINDOW_ID"

    local files_state_dir="${XDG_RUNTIME_DIR:-/tmp}/kitty-files"
    local cwd_state_dir="${XDG_RUNTIME_DIR:-/tmp}/kitty-cwd"

    local requested_level=""
    local requested_size=""
    local should_set_level="no"
    local should_set_size="no"
    local should_open_only="no"
    local should_close_only="no"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --level)
                requested_level="${2:-}"

                if [[ -z "$requested_level" || ! "$requested_level" =~ "^[0-9]+$" || "$requested_level" -lt 1 ]]; then
                    echo "Usage: files [--open] [--close] [--watch <window-id>] [--level <positive-number>] [--size <1-100>]"
                    return 1
                fi

                should_set_level="yes"
                shift 2
                ;;

            --size)
                requested_size="${2:-}"

                if [[ -z "$requested_size" || ! "$requested_size" =~ "^[0-9]+$" || "$requested_size" -lt 1 || "$requested_size" -gt 100 ]]; then
                    echo "Usage: files [--open] [--close] [--watch <window-id>] [--level <positive-number>] [--size <1-100>]"
                    return 1
                fi

                should_set_size="yes"
                shift 2
                ;;

            --watch)
                watch_window_id="${2:-}"

                if [[ -z "$watch_window_id" || ! "$watch_window_id" =~ "^[0-9]+$" ]]; then
                    echo "Usage: files --watch <window-id>"
                    return 1
                fi

                shift 2
                ;;

            --open)
                should_open_only="yes"
                shift
                ;;

            --close)
                should_close_only="yes"
                shift
                ;;

            *)
                echo "Usage: files [--open] [--close] [--watch <window-id>] [--level <positive-number>] [--size <1-100>]"
                return 1
                ;;
        esac
    done

    local cwd_file="$cwd_state_dir/$watch_window_id"
    local files_window_id_file="$files_state_dir/$watch_window_id.window-id"
    local files_level_file="$files_state_dir/$watch_window_id.level"
    local files_size_file="$files_state_dir/$watch_window_id.size"

    mkdir -p "$files_state_dir" "$cwd_state_dir"

    if [[ "$watch_window_id" == "$caller_window_id" ]]; then
        print -r -- "$PWD" > "$cwd_file"
    elif [[ ! -f "$cwd_file" ]]; then
        print -r -- "$PWD" > "$cwd_file"
    fi

    if [[ "$should_set_level" == "yes" ]]; then
        print -r -- "$requested_level" > "$files_level_file"
    elif [[ ! -f "$files_level_file" ]]; then
        print -r -- "1" > "$files_level_file"
    fi

    if [[ "$should_set_size" == "yes" ]]; then
        print -r -- "$requested_size" > "$files_size_file"
    elif [[ ! -f "$files_size_file" ]]; then
        print -r -- "20" > "$files_size_file"
    fi

    local current_size="$(cat "$files_size_file" 2>/dev/null)"
    if [[ -z "$current_size" || ! "$current_size" =~ "^[0-9]+$" || "$current_size" -lt 1 || "$current_size" -gt 100 ]]; then
        current_size="20"
        print -r -- "$current_size" > "$files_size_file"
    fi

    local existing_files_window_id=""
    if [[ -f "$files_window_id_file" ]]; then
        existing_files_window_id="$(cat "$files_window_id_file" 2>/dev/null)"
    fi

    local files_window_exists="no"
    if [[ -n "$existing_files_window_id" ]] && kitty @ ls | grep -q "\"id\": $existing_files_window_id"; then
        files_window_exists="yes"
    fi

    if [[ "$should_close_only" == "yes" ]]; then
        if [[ "$files_window_exists" == "yes" ]]; then
            kitty @ close-window --match "id:$existing_files_window_id" >/dev/null 2>&1
        fi

        rm -f "$files_window_id_file"
        return 0
    fi

    if [[ "$should_open_only" == "no" && "$should_set_level" == "no" && "$should_set_size" == "no" && "$files_window_exists" == "yes" ]]; then
        kitty @ close-window --match "id:$existing_files_window_id" >/dev/null 2>&1
        rm -f "$files_window_id_file"
        return 0
    fi

    if [[ "$files_window_exists" == "yes" ]]; then
        kitty @ close-window --match "id:$existing_files_window_id" >/dev/null 2>&1
        rm -f "$files_window_id_file"
    fi

    kitty @ goto-layout tall >/dev/null

    local files_window_id="$(
        kitty @ launch --cwd=current --title=files --bias "$current_size" --env "FILES_CWD_FILE=$cwd_file" --env "FILES_LEVEL_FILE=$files_level_file" --env "FILES_WATCH_WINDOW_ID=$watch_window_id" zsh -lc '
            last_signature=""

            while true; do
                if ! kitty @ ls | grep -q "\"id\": $FILES_WATCH_WINDOW_ID"; then
                    exit 0
                fi

                current_cwd="$(cat "$FILES_CWD_FILE" 2>/dev/null)"
                current_level="$(cat "$FILES_LEVEL_FILE" 2>/dev/null)"

                if [[ -z "$current_level" || ! "$current_level" =~ "^[0-9]+$" || "$current_level" -lt 1 ]]; then
                    current_level=1
                fi

                if [[ -n "$current_cwd" && -d "$current_cwd" ]]; then
                    current_signature="$(
                        print -r -- "cwd $current_cwd"
                        print -r -- "level $current_level"
                        find "$current_cwd" -maxdepth "$current_level" -mindepth 1 -exec stat -f "%N %m %z" {} + 2>/dev/null | sort
                    )"

                    if [[ "$current_signature" != "$last_signature" ]]; then
                        clear

                        if command -v eza >/dev/null 2>&1; then
                            eza --tree --level="$current_level" --color always --no-filesize --icons --git -l --no-user --no-permissions --no-time --group-directories-last --time-style long-iso --modified -s modified --reverse "$current_cwd"

                            if [[ -z "$(find "$current_cwd" -maxdepth 1 -mindepth 1 -print -quit 2>/dev/null)" ]]; then
                                print
                                printf "\033[37m(empty folder)\033[0m\n"
                            fi
                        elif command -v tree >/dev/null 2>&1; then
                            tree -L "$current_level" -a -I ".git|node_modules|target|dist|build" "$current_cwd"
                        else
                            find "$current_cwd" -maxdepth "$current_level" -mindepth 1 -not -path "*/.git/*" -not -path "*/node_modules/*" | sed "s|^$current_cwd/||" | sort
                        fi

                        last_signature="$current_signature"
                    fi
                fi

                sleep 0.2
            done
        '
    )"

    print -r -- "$files_window_id" > "$files_window_id_file"
    kitty @ focus-window --match "id:$caller_window_id" >/dev/null 2>&1
}