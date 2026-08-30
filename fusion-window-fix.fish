#!/usr/bin/env fish

echo "[Fusion180] Window watcher started"

while true
    set main_windows (xwininfo -root -tree 2>/dev/null |
        string match -r '0x[0-9a-fA-F]+ "Home - Autodesk Fusion.*"')

    for main_line in $main_windows
        set main_id (string split ' ' -- $main_line)[1]

        set fusion_windows (xwininfo -root -tree 2>/dev/null |
            string match -r '0x[0-9a-fA-F]+ "Fusion360".*')

        for line in $fusion_windows
            set wid (string split ' ' -- $line)[1]

             if test "$wid" = "$main_id"
                continue
            end

            set info (xwininfo -id $wid 2>/dev/null)

            if test $status -ne 0
                continue
            end

            # Override Redirect = yes
            if not string match -q '*Override Redirect State: yes*' -- $info
                continue
            end

             set transient (xprop -id $wid WM_TRANSIENT_FOR 2>/dev/null)

             if not string match -q "*window id # $main_id*" -- $transient
                continue
            end

            # input=False
            set hints (xprop -id $wid WM_HINTS 2>/dev/null)

            if string match -q '*Client accepts input or input focus: False*' -- $hints
                echo "[Fusion180] Problematic Fusion360 dialog detected: $wid"
                echo "[Fusion180] Parent: $main_id"
                echo "[Fusion180] Unmapping..."

                xdotool windowunmap $wid 2>/dev/null
            end
        end
    end

    sleep 0.2
end
