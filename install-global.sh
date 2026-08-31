#!/bin/sh

set -eu

PROGRAM_NAME=${0##*/}
BEGIN_MARKER='<!-- BEGIN inq-codex-multi-agents -->'
END_MARKER='<!-- END inq-codex-multi-agents -->'
MAX_CONCURRENT_THREADS=4
TARGET_CODEX_HOME=''
TARGET_WAS_SET=false
WHAT_IF=false

usage() {
    cat <<EOF
Usage: $PROGRAM_NAME [options]

Install this repository's Codex configuration as personal defaults.

Options:
  --target-codex-home PATH       Install under PATH instead of CODEX_HOME or \$HOME/.codex.
  --max-concurrent-threads N     Set the per-session agent thread limit (1..64, default: 4).
  --what-if                      Show planned changes without writing target or backup files.
  --help                         Show this help message.
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case $1 in
        --target-codex-home)
            [ "$#" -ge 2 ] || fail '--target-codex-home requires a path.'
            TARGET_CODEX_HOME=$2
            TARGET_WAS_SET=true
            shift 2
            ;;
        --max-concurrent-threads)
            [ "$#" -ge 2 ] || fail '--max-concurrent-threads requires a number.'
            MAX_CONCURRENT_THREADS=$2
            shift 2
            ;;
        --what-if)
            WHAT_IF=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        --)
            shift
            [ "$#" -eq 0 ] || fail "Unexpected argument: $1"
            ;;
        -* )
            fail "Unknown option: $1"
            ;;
        *)
            fail "Unexpected argument: $1"
            ;;
    esac
done

if ! MAX_CONCURRENT_THREADS=$(awk -v value="$MAX_CONCURRENT_THREADS" 'BEGIN {
    if (value !~ /^[0-9]+$/ || value < 1 || value > 64) {
        exit 1
    }
    printf "%d", value
}'); then
    fail '--max-concurrent-threads must be an integer from 1 through 64.'
fi

if [ "$TARGET_WAS_SET" = false ]; then
    if [ -n "${CODEX_HOME:-}" ]; then
        TARGET_CODEX_HOME=$CODEX_HOME
    else
        [ -n "${HOME:-}" ] || fail 'HOME is not set and no target Codex home was provided.'
        TARGET_CODEX_HOME=$HOME/.codex
    fi
fi

[ -n "$TARGET_CODEX_HOME" ] || fail 'The target Codex home must not be empty.'

normalize_absolute_path() {
    awk -v path="$1" 'BEGIN {
        count = split(path, parts, "/")
        depth = 0
        for (i = 1; i <= count; i++) {
            if (parts[i] == "" || parts[i] == ".") {
                continue
            }
            if (parts[i] == "..") {
                if (depth > 0) {
                    delete stack[depth]
                    depth--
                }
                continue
            }
            stack[++depth] = parts[i]
        }
        result = "/"
        for (i = 1; i <= depth; i++) {
            if (i > 1) {
                result = result "/"
            }
            result = result stack[i]
        }
        print result
    }'
}

case $TARGET_CODEX_HOME in
    /*) target_candidate=$TARGET_CODEX_HOME ;;
    *) target_candidate=$(pwd)/$TARGET_CODEX_HOME ;;
esac
target_root=$(normalize_absolute_path "$target_candidate")
[ "$target_root" != / ] || fail "Refusing to use a filesystem root as the target Codex home: $target_root"

script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
source_agents_file=$script_dir/AGENTS.md
source_agents_directory=$script_dir/.codex/agents
target_agents_file=$target_root/AGENTS.md
target_config_file=$target_root/config.toml
target_agents_directory=$target_root/agents
backup_root=$target_root/backups/inq-codex-multi-agents/$(date '+%Y%m%d-%H%M%S')

[ -f "$source_agents_file" ] || fail "Source AGENTS.md was not found: $source_agents_file"
[ -d "$source_agents_directory" ] || fail "Source agents directory was not found: $source_agents_directory"

source_agent_found=false
for source_agent in "$source_agents_directory"/*.toml; do
    if [ -f "$source_agent" ]; then
        source_agent_found=true
        break
    fi
done
[ "$source_agent_found" = true ] || fail "No custom agent TOML files were found in: $source_agents_directory"

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/inq-codex-install.XXXXXX") || fail 'Could not create a temporary directory.'
cleanup() {
    if [ -n "${temp_dir:-}" ] && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
    fi
}
trap cleanup 0 1 2 15

managed_block=$temp_dir/managed-agents.md
{
    printf '%s\n' "$BEGIN_MARKER"
    awk '{ lines[NR] = $0 } END {
        last = NR
        while (last > 0 && lines[last] ~ /^[[:space:]]*$/) {
            last--
        }
        for (i = 1; i <= last; i++) {
            print lines[i]
        }
    }' "$source_agents_file"
    printf '%s\n' "$END_MARKER"
} > "$managed_block"

normalize_existing_file() {
    input_file=$1
    output_file=$2
    if [ -f "$input_file" ]; then
        awk '{ sub(/\r$/, ""); print }' "$input_file" > "$output_file"
    else
        : > "$output_file"
    fi
}

prepare_merged_agents() {
    existing_file=$1
    output_file=$2

    marker_info=$(awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        function count_token(line, token, base, is_begin, position, found) {
            position = 1
            while ((found = index(substr(line, position), token)) > 0) {
                found += position - 1
                if (is_begin) {
                    begin_count++
                    if (begin_count == 1) begin_offset = base + found
                } else {
                    end_count++
                    if (end_count == 1) end_offset = base + found
                }
                position = found + length(token)
            }
        }
        {
            count_token($0, begin, offset, 1)
            count_token($0, end, offset, 0)
            offset += length($0) + 1
        }
        END { print begin_count + 0, end_count + 0, begin_offset + 0, end_offset + 0 }
    ' "$existing_file")
    set -- $marker_info
    begin_count=$1
    end_count=$2
    begin_offset=$3
    end_offset=$4

    if [ "$begin_count" -gt 1 ] || [ "$end_count" -gt 1 ]; then
        fail 'AGENTS.md contains multiple managed marker blocks.'
    fi
    if [ "$begin_count" -ne "$end_count" ]; then
        fail 'AGENTS.md contains only one installation marker. Restore the marker pair or remove the incomplete marker before retrying.'
    fi
    if [ "$begin_count" -eq 1 ] && [ "$begin_offset" -ge "$end_offset" ]; then
        fail 'AGENTS.md installation markers are out of order.'
    fi

    if [ "$begin_count" -eq 1 ]; then
        awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
            NR == FNR { managed[++managed_count] = $0; next }
            state == 0 {
                start = index($0, begin)
                if (start == 0) {
                    print
                    next
                }
                prefix = substr($0, 1, start - 1)
                if (prefix != "") print prefix
                for (i = 1; i <= managed_count; i++) print managed[i]
                remainder = substr($0, start + length(begin))
                finish = index(remainder, end)
                if (finish > 0) {
                    suffix = substr(remainder, finish + length(end))
                    if (suffix != "") print suffix
                    state = 2
                } else {
                    state = 1
                }
                next
            }
            state == 1 {
                finish = index($0, end)
                if (finish > 0) {
                    suffix = substr($0, finish + length(end))
                    if (suffix != "") print suffix
                    state = 2
                }
                next
            }
            { print }
        ' "$managed_block" "$existing_file" > "$output_file"
    else
        awk '
            NR == FNR { managed[++managed_count] = $0; next }
            { existing[++existing_count] = $0 }
            END {
                for (i = 1; i <= existing_count; i++) print existing[i]
                if (existing_count > 0) print ""
                for (i = 1; i <= managed_count; i++) print managed[i]
            }
        ' "$managed_block" "$existing_file" > "$output_file"
    fi
}

prepare_merged_root_config() {
    existing_file=$1
    output_file=$2

    root_counts=$(awk '
        /^[[:blank:]]*\[/ { in_table = 1 }
        !in_table && /^[[:blank:]]*model[[:blank:]]*=/ { model_count++ }
        !in_table && /^[[:blank:]]*model_reasoning_effort[[:blank:]]*=/ { effort_count++ }
        END { print model_count + 0, effort_count + 0 }
    ' "$existing_file")
    set -- $root_counts
    model_count=$1
    effort_count=$2

    [ "$model_count" -le 1 ] || fail 'config.toml contains duplicate top-level model keys.'
    [ "$effort_count" -le 1 ] || fail 'config.toml contains duplicate top-level model_reasoning_effort keys.'

    awk '
        function emit_missing() {
            if (!model_written) print "model = \"gpt-5.6-sol\""
            if (!effort_written) print "model_reasoning_effort = \"high\""
        }
        /^[[:blank:]]*\[/ {
            if (!in_table) {
                emit_missing()
                in_table = 1
            }
            print
            next
        }
        !in_table && /^[[:blank:]]*model[[:blank:]]*=/ {
            print "model = \"gpt-5.6-sol\""
            model_written = 1
            next
        }
        !in_table && /^[[:blank:]]*model_reasoning_effort[[:blank:]]*=/ {
            print "model_reasoning_effort = \"high\""
            effort_written = 1
            next
        }
        { print }
        END {
            if (!in_table) emit_missing()
        }
    ' "$existing_file" > "$output_file"
}

prepare_merged_config() {
    existing_file=$1
    output_file=$2
    setting_line="max_concurrent_threads_per_session = $MAX_CONCURRENT_THREADS"

    config_counts=$(awk '
        /^[[:blank:]]*\[agents\][[:blank:]]*(#.*)?$/ {
            section_count++
            in_agents = 1
            next
        }
        /^[[:blank:]]*\[/ { in_agents = 0 }
        in_agents && /^[[:blank:]]*max_concurrent_threads_per_session[[:blank:]]*=/ { key_count++ }
        END { print section_count + 0, key_count + 0 }
    ' "$existing_file")
    set -- $config_counts
    section_count=$1
    key_count=$2

    [ "$section_count" -le 1 ] || fail 'config.toml contains more than one [agents] table.'
    [ "$key_count" -le 1 ] || fail 'The [agents] table contains duplicate max_concurrent_threads_per_session keys.'

    if [ "$section_count" -eq 0 ]; then
        awk -v setting="$setting_line" '
            { lines[NR] = $0 }
            END {
                last = NR
                while (last > 0 && lines[last] ~ /^[[:blank:]]*$/) last--
                for (i = 1; i <= last; i++) print lines[i]
                if (last > 0) print ""
                print "[agents]"
                print setting
            }
        ' "$existing_file" > "$output_file"
        return
    fi

    awk -v setting="$setting_line" -v key_count="$key_count" '
        /^[[:blank:]]*\[agents\][[:blank:]]*(#.*)?$/ {
            print
            in_agents = 1
            if (key_count == 0) print setting
            next
        }
        in_agents && /^[[:blank:]]*max_concurrent_threads_per_session[[:blank:]]*=/ {
            line = $0
            indent = line
            sub(/[^[:blank:]].*$/, "", indent)
            comment = ""
            if (match(line, /[[:blank:]]+#.*/)) comment = substr(line, RSTART)
            print indent setting comment
            next
        }
        /^[[:blank:]]*\[/ { in_agents = 0 }
        { print }
    ' "$existing_file" > "$output_file"
}

backup_existing_file() {
    existing_file=$1
    relative_path=$2
    [ -f "$existing_file" ] || return 0
    backup_file=$backup_root/$relative_path
    mkdir -p "$(dirname "$backup_file")"
    cp "$existing_file" "$backup_file"
}

changed_files=0
planned_files=0

install_file() {
    prepared_file=$1
    destination_file=$2
    relative_path=$3

    if [ -f "$destination_file" ] && cmp -s "$prepared_file" "$destination_file"; then
        return
    fi

    planned_files=$((planned_files + 1))
    if [ "$WHAT_IF" = true ]; then
        printf 'Would update: %s\n' "$destination_file"
        return
    fi

    backup_existing_file "$destination_file" "$relative_path"
    mkdir -p "$(dirname "$destination_file")"
    cp "$prepared_file" "$destination_file"
    changed_files=$((changed_files + 1))
    printf 'Updated: %s\n' "$destination_file"
}

existing_agents=$temp_dir/existing-agents.md
merged_agents=$temp_dir/merged-agents.md
normalize_existing_file "$target_agents_file" "$existing_agents"
prepare_merged_agents "$existing_agents" "$merged_agents"
install_file "$merged_agents" "$target_agents_file" 'AGENTS.md'

existing_config=$temp_dir/existing-config.toml
root_merged_config=$temp_dir/root-merged-config.toml
merged_config=$temp_dir/merged-config.toml
normalize_existing_file "$target_config_file" "$existing_config"
prepare_merged_root_config "$existing_config" "$root_merged_config"
prepare_merged_config "$root_merged_config" "$merged_config"
install_file "$merged_config" "$target_config_file" 'config.toml'

for source_agent in "$source_agents_directory"/*.toml; do
    [ -f "$source_agent" ] || continue
    agent_name=${source_agent##*/}
    install_file "$source_agent" "$target_agents_directory/$agent_name" "agents/$agent_name"
done

printf 'Codex home: %s\n' "$target_root"
if [ "$WHAT_IF" = true ]; then
    if [ "$planned_files" -gt 0 ]; then
        printf 'Planned %s file change(s); no target or backup files were written.\n' "$planned_files"
    else
        printf 'No file changes are required.\n'
    fi
elif [ "$changed_files" -gt 0 ]; then
    printf 'Updated %s file(s).\n' "$changed_files"
    printf 'Backups of replaced files (when applicable): %s\n' "$backup_root"
else
    printf 'No file changes were required.\n'
fi

override_file=$target_root/AGENTS.override.md
if [ -f "$override_file" ]; then
    printf 'Warning: AGENTS.override.md exists and takes precedence over AGENTS.md: %s\n' "$override_file" >&2
fi

printf 'Start a new Codex session to load the updated global configuration.\n'
