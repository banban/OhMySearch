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
            else if (params.selected == "3_1") {
                $("#ChosenOptions").val($("#ChosenOptions").val().replace("3_2,", ""));
            }
            else if (params.selected == "3_2") {
                $("#ChosenOptions").val($("#ChosenOptions").val().replace("3_1,", ""));
            }
        }
        else if (params.deselected) {
            $("#ChosenOptions").val($("#ChosenOptions").val().replace(params.deselected + ",", ""));
        }
    });
});
