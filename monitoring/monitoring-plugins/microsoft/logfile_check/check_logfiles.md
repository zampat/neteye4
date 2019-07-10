Usage of check_logfiles:


Usage :

'C:\Program Files\ICINGA2\/sbin/check_logfiles.exe' '-f' 'C:\Program Files\ICINGA2\sbin\check_logfiles.cfg'


Command definition:

object CheckCommand "logfile_windows" {
    import "plugin-check-command"
    command = [ PluginDir + "/check_logfiles.exe" ]
    timeout = 1m
    arguments += {
        "-f" = {
            required = true
            value = "$check_logfiles_cfg$"
        }
    }
}


