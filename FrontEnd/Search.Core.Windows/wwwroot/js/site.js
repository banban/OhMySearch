// Write your Javascript code.
function AddFilter(filter, value) {
    $("#QueryTerm").val("Name=The quick brown fox");

}
$(document).ready(function () {

    $('#editDialog')
        .on('hide.bs.modal', function () {
            $('#editDialog')
                .removeData(); //destroy cached content
            })
        .on('show.bs.modal', function () {
            $('.modal-content').css('height',$( window ).height()*0.9);
        })
        //.on('shown.bs.modal', function () { //make it draggable
        //    $("input[type='submit']").on("click", function () {
        //        document.body.style.cursor = 'wait';
        //        $("body").css("cursor", "progress");
        //    });
        //})
    ;

    $(".chosen-select").chosen({
        include_group_label_in_selected: true,
        disable_search_threshold: 10,
        no_results_text: "Incorrect option:",
        width: "70%"
    }).change(function (event, params) {
        if (params.selected) {
            console.log("selected " + params.selected);
            $("#ChosenOptions").val($("#ChosenOptions").val() + params.selected + "+");
            if (params.selected == "3_1") {
                $("#QueryTerm").val("Name=Value");
            }
            else if (params.selected == "3_2") {
                $("#QueryTerm").val("The qick broon foox");
            }
            else if (params.selected == "3_3") {
                $("#QueryTerm").val("{'term': {'Content': 'test'}}");
            }
            else if (params.selected == "3_4") {
                $("#QueryTerm").val("Perth");
            }
            else if (params.selected == "6_2") {
                $('#slider-score-placeholder').show();
            }

            ///some options can conflict with others
            //else if (params.selected == "4_1") { 
            //    $("#ChosenOptions").val($("#ChosenOptions").val().replace("4_2,", ""));
            //}
            //else if (params.selected == "4_2") {
            //    $("#ChosenOptions").val($("#ChosenOptions").val().replace("4_1,", ""));
            //}

}
        else if (params.deselected) {
            console.log("deselected " + params.deselected);
            if (params.deselected == "6_2") {
                $("#minscore2").val(0);
                $("#MinScore").val(0);
                $('#slider-score-placeholder').hide();
            }

            $("#ChosenOptions").val($("#ChosenOptions").val().replace(params.deselected + "+", ""));
        }
    });


    var themes = {
        "default": "~/Content/bootstrap.min.css",
        "amelia": "../lib/bootswatch/amelia/bootstrap.min.css",
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
