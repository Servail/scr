Features out-of-the-box:  
- basic brightness, contrast, gamma, saturation, sharpness adjustment (saturation should also work with older amd/nvidia GPUs because of picom/shader-based approach)  
- dim: suppresses light shades not touching mids and saturated colors, with normalization (i.e. can dim bright text)  
- black-lightness: brightness alternative that doesn't affect saturated colors so avoids overall bleakness  
- roughness: sharpness with bigger kernel, improves contrast and emphasizes details (performance-heavy, set as fullscreen only)  
- fakehdr: imitates natural colorfulness by compensating for RGB output nuances thus boosting saturation on color shades exponentially and suppressing on bright colors and also slightly correcting CMY balance, uses saturation value as initial factor (set to active fullscreen window only)  
- lum: boosts scene luminance based on its average value, so no more flashbangs or too dark scenes (performance-heavy, set to active fullscreen window only)  
- autobalance: tries to remove scene dominant color improving other colors (performance impact shared with lum, set to active fullscreen window only)  
- VR SBS 3D: experimental side-by-side duplicate/split zoomed/squished/scaled view for HMDs, with optional pincushion distortion, chromatic abberation suppression, IPD adjustment, fullscreen effects etc. (some preview is hidden in negative UseEffects values, currently adjustable through shader editing)  

Prerequisites:  
- bc, xcalib, picom  

WARNING! If something goes wrong (like contrast was set to 0 - which means black screen) use commands:  
- xcalib -c  
- pkill picom  
These can be blindly-typed into terminal or entered from ssh or another tty (Ctrl+Alt+F1-12, then go back to original graphical session which is probably at tty7 - Ctrl+Alt+F7)  

Usage:  
- Bind scripts named *-more *-less *-reset to hotkeys  
- Run current-apply.sh at startup for persistence (e.g. link and enable scr-apply.service for systemd)  
- To avoid unnecessary disk writes, run service-start.sh on startup and service-stop.sh on shutdown (e.g. link and enable scr-ram.service for systemd): it moves active profile to RAM (/run/user/$USER/scr/)  
- Write your own scripts based on existing framework (which is mostly chvar.sh and profiles)  
- Run profile-save.sh or profile-load.sh for usage  

Known issues:  
- if visual settings are not updated randomly, try switching currently active window back and forth (notice that visual update for picom-related settings is delayed until you settle with some value, to avoid unnecessary shader recompilation)  
- xcalib versions can differ, try swapping xcalib-set.sh with xcalib-set.sh.old if former outputs syntax errors  
