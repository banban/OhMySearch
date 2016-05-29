// Write your Javascript code.
//https://www.sitepoint.com/jquery-infinite-scrolling-demos/
$(document).ready(function () {
    $(".chosen-select").chosen({
        include_group_label_in_selected: true,
        disable_search_threshold: 10,
        no_results_text: "Incorrect option:",
        width: "70%"
    }).change(function (event, params) {
        if (params.selected) {
            $("#ChosenOptions").val($("#ChosenOptions").val() + params.selected + ",");
            if (params.selected == "2_1") {
                $("#QueryTerm").val("The quick brown fox");
            }
            else if (params.selected == "2_2") {
                $("#QueryTerm").val("The qick broon foox");
            }
            else if (params.selected == "2_3") {
                $("#QueryTerm").val("/1/2/3");
            }
            else if (params.selected == "2_4") {
                $("#QueryTerm").val("Perth");
            }
            ///some options can conflict with others
            //else if (params.selected == "3_1") { 
            //    $("#ChosenOptions").val($("#ChosenOptions").val().replace("3_2,", ""));
            //}
            //else if (params.selected == "3_2") {
            //    $("#ChosenOptions").val($("#ChosenOptions").val().replace("3_1,", ""));
            //}
        }
        else if (params.deselected) {
            $("#ChosenOptions").val($("#ChosenOptions").val().replace(params.deselected + ",", ""));
        }
    });


    var themes = {
        "default": "~/Content/bootstrap.min.css",
        "amelia": "//bootswatch.com/2/amelia/bootstrap.min.css",
        "cerulean": "../lib/bootswatch/cerulean/bootstrap.min.css",
        "cosmo": "../lib/bootswatch/cosmo/bootstrap.min.css",
        "cyborg": "../lib/bootswatch/cyborg/bootstrap.min.css",
        "darkly": "../lib/darkly/bootstrap.min.css",
        "flatly": "../lib/bootswatch/flatly/bootstrap.min.css",
        "journal": "../lib/bootswatch/journal/bootstrap.min.css",
        "lumen": "../lib/bootswatch/lumen/bootstrap.min.css",
        "paper": "../lib/bootswatch/paper/bootstrap.min.css",
        "readable": "../lib/bootswatch/readable/bootstrap.min.css",
        "sandstone": "../lib/sandstone/bootstrap.min.css",
        "simplex": "../lib/bootswatch/simplex/bootstrap.min.css",
        "slate": "../lib/bootswatch/slate/bootstrap.min.css",
        "spacelab": "../lib/bootswatch/spacelab/bootstrap.min.css",
        "superhero": "../lib/bootswatch/superhero/bootstrap.min.css",
        "united": "../lib/bootswatch/united/bootstrap.min.css",
        "yeti": "../lib/bootswatch/yeti/bootstrap.min.css"
    }
    $(function () {
        var themesheet = $('<link href="' + themes['default'] + '" rel="stylesheet" />');
        themesheet.appendTo('head');
        $('.theme-link').click(function () {
            var themeurl = themes[$(this).attr('data-theme')];
            themesheet.attr('href', themeurl);
        });
    });

});
