/*
:title:     bug.n - tiling window management
:copyright: (c) 2022 joten <https://github.com/joten>
                2010 - 2021 https://github.com/fuhsjr00/bug.n/graphs/contributors
:license:  GNU General Public License version 3 (http://www.gnu.org/licenses/gpl-3.0.txt)

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

;; Write messages from a source (e.g an Object.function) to a cache object `Logging.cache` 
;; relative to the current `Logging.level`, with or without a timestamp. The cache can be 
;; written to a destination (e.g. a text file or web interface) and emptied afterwards.
;; Possible logging levels:
;;   CRITICAL = 1
;;   ERROR    = 2
;;   WARNING  = 3
;;   INFO     = 4
;;   DEBUG    = 5
Logging__init(filename := "", interval := 4200, level := 5) {
  Global Logging

  Logging := {cache: []
            , filename: filename
            , interval: interval
            , labels: ["", "CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"]
            , level: level
            , timeFormat: "yyyy-MM-dd HH:mm:ss"}
  Logging_info("Logging started on level ``" . Logging.labels[Logging.level + 1] . "``.", "Logging__init")
}

Logging_getTimestamp() {
  Global Logging
  
  FormatTime, timestamp, , % Logging.timeFormat
  Return, timestamp
}

Logging_setLevel(level := 0, delta := 0) {
  ;; If `level = 0`, delta should be -1 or +1 to de- or increment `Logging.level`.
  ;; The result should be between 1 and the maximum level (label index).
  Global Logging
  
  level := level ? level : Logging.level
  level := Min(Max(level + delta, 1), Logging.labels.Length() - 1)
  If (level != Logging.level) {
    Logging.level := level
    Logging_write("Level set to ``" . Logging.labels[level + 1] . "``.", "Logging_setLevel")
  }
}

Logging_write(msg, src := "", level := 0, timestamp := True) {
  ;; src normally is the Object.function, where the logging function was called from.
  ;; If `level = 0`, the message is logged independent from the current Logging.level.
  ;; Instead of the level (integer), the label (text) is added to the entry.
  ;; If `timestamp == False`, the date and time is not added to the entry.
  Global Logging
  
  If (Logging.level >= level) {
    item := []
    item.push(timestamp ? Logging_getTimestamp() : "")
    item.push(Logging.labels[level + 1])
    item.push(src)
    item.push(msg)
    Logging.cache.push(item)
  }
}
;; Explicit functions for the individual log levels, including timestamps.
Logging_critical(msg, src) {
  Logging_write(msg, src, 1)
}
Logging_error(msg, src) {
  Logging_write(msg, src, 2)
}
Logging_warning(msg, src) {
  Logging_write(msg, src, 3)
}
Logging_info(msg, src) {
  Logging_write(msg, src, 4)
}
Logging_debug(msg, src) {
  Logging_write(msg, src, 5)
}

Logging_writeCacheToFile(overwrite := False) {
  Global Logging

  If (Logging.filename != "") {
    text := ""
    For i, item in Logging.cache {
      ;; timestamp, level, src, msg
      text .= Format("{:19}", item[1]) . " "
            . " " . Format("{:-8}", item[2]) . " "
            . (item[3] != "" ? "**" . item[3] . "**" : "") . " "
            . item[4] . "`n"
    }
    If (overwrite) {
      FileDelete, % Logging.filename
    }
    FileAppend, % text, % Logging.filename
    Logging.cache := []
    ;; Run, % "open " . Logging.filename
  }
}
