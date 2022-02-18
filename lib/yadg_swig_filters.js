/**
 * This is a collection of "swig" templating engine filters which are used
 * within template definitions that are defined by YADG. These filters were
 * written by YADG maintainers and found here:
 *
 * https://gitlab.com/Slack06/yadg/-/blob/develop/static/js/swig.custom.js
 *
 * This file is consumed by the command line utility for swig.
 */
module.exports = {
  artistsbytype: function (input, type) {
    var out = [];
    for (var i = 0; i < input.length; i++) {
      artist = input[i];
      if (artist["types"].indexOf(type) > -1) {
        out.push(artist);
      }
    }
    return out;
  },
  formatseconds: function (input, with_zeros) {
    var secs = Math.round(input);
    var hours = Math.floor(secs / (60 * 60));

    var divisor_for_minutes = secs % (60 * 60);
    var minutes = Math.floor(divisor_for_minutes / 60);

    var divisor_for_seconds = divisor_for_minutes % 60;
    var seconds = Math.ceil(divisor_for_seconds);

    var out = "";
    if (hours > 0) {
      if (with_zeros && hours < 10) out += "0";
      out += hours + ":";
    }
    if (with_zeros && minutes < 10) out += "0";
    out += minutes;
    out += ":";
    if (seconds < 10) out += "0";
    out += seconds;
    return out;
  },
  isdigit: function (input) {
    var regex = /\D/;
    return !regex.test(input);
  },
  wrap: function (input, artist_format_string, separator, last_separator) {
    var out = "",
      artist_count = input.length;

    for (var i = 0; i < artist_count; i++) {
      var artist = input[i],
        artist_name = "";

      if (artist.isVarious === true) {
        artist_name = "Various Artists";
      } else {
        artist_name = artist.name;
      }
      out += artist_format_string.replace("%s", artist_name);

      if (i < artist_count - 2) {
        out += separator;
      } else if (i < artist_count - 1) {
        out += last_separator;
      }
    }
    return out;
  },
};
