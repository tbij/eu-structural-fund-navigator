google.load("language", "1");

function normalize_html(html) {
  return html.replace(/\n/g, "").replace(/<br \/>/g, "").replace(/<br>/g, "").replace(/-/g," ").replace(/\*/g,"").replace(/^\s+/, "").replace(/\s+$/, "").replace(/\s\s/g," ");
}

function initialize() {
  var cells = document.getElementsByTagName('span');
  
  for (var i = 0; i < cells.length; ++i) {
    var item = cells[i];
    if (item.className == "description") {
      var to_language = item.parentNode.className;

      if (to_language != 'en') {
        var id = item.id.replace("description_","");        
        var text_length = normalize_html(item.innerHTML).length;

        if(text_length > 0) {
          var text = item.innerHTML;
          text = id + " " + text;
  
          google.language.translate(text, to_language, "en", function(result) {
            var translation = result.translation;
            if (translation) {
              var index = translation.split(" ")[0];
              translation = translation.replace(index + " ", "");
              var input = normalize_html(document.getElementById("description_" + index).innerHTML);
              // alert(input);
              var normalized_translation = normalize_html(translation);
              if (normalized_translation != input) {
                var element = document.getElementById("translation_" + index);
                element.innerHTML = translation;
              }
            }
          });
        }
      }
    }
  }

  google.language.getBranding('google_attribution');
}
google.setOnLoadCallback(initialize);
