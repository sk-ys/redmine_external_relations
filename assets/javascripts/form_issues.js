$(function() {
    let local_app_name = ExRels.settings.app_name;

    function rev_to_from(to_from){
        return (to_from == "to" ? "from" : "to");
    }

    let apikey = '';
    function getApiKey(app_path) {
        let target_path = app_path + '/my/api_key'
        return function() {
            return $.get(target_path).done(function(data){
                apikey = $('#content > div.box > pre', $(data)).first().text();
            });
        };
    }

    function addIssue(app_path, data) {
        return function() {
            $.support.cors = true;
            return $.ajax({
                type: 'POST',
                url: app_path + '/external_relations/items.json',
                headers: {
                    'X-Redmine-API-Key': apikey
                },
                dataType: 'text',
                contentType: 'application/json',
                data: JSON.stringify(data)
            });
        };
    }

    function addExRels(to_from) {
        if (!confirm(ExRels.settings.message.confirm_add_link)) {
            return false;
        }

        let issue_from_id = $("#ex_rel_" + to_from + "_issue_from_id").val();

        if (to_from == "to") {
            var issue_to_app_name = getCurrentSelectedAppName(to_from);
            if (issue_to_app_name == 'local') {
                issue_to_app_name = local_app_name;
            }
            var issue_from_app_name = local_app_name;
        } else {
            var issue_from_app_name = getCurrentSelectedAppName(to_from);
            if (issue_from_app_name == 'local') {
                issue_from_app_name = local_app_name;
            }
            var issue_to_app_name = local_app_name;
        }

        let issue_to_id = $("#ex_rel_" + to_from + "_issue_to_id").val();

        let data = {}
        data['ex_rel_' + to_from] = {
                'issue_from_id': issue_from_id,
                'issue_from_app_name': issue_from_app_name,
                'issue_to_id': issue_to_id,
                'issue_to_app_name': issue_to_app_name
            }

        let app_path = '/' + issue_to_app_name;
        let defer = $.Deferred();
        let promise = defer.promise();

        promise = promise.then(getApiKey(app_path));
        promise = promise.then(addIssue(app_path, data));

        promise
        .done(function() {
            if (to_from == "to") {
                var issue_id = issue_from_id;
            } else {
                var issue_id = issue_to_id;
            }
            let data_redraw = {
                'issue_id': issue_id,
                'data_type': to_from
            }
            redrawTable(data_redraw);
        })
        .fail(function() {
            alert(ExRels.settings.message.error_add_link);
        });
        defer.resolve();
        return false;
    }

    function redrawTable(data) {
        $.support.cors = true;
        $.ajax({
            type    : 'patch',
            url     : '/' + local_app_name + '/external_relations/redraw_table.js',
            headers: {
                'X-Redmine-API-Key': apikey
            },
            data    : data
        });
    }

    function getCurrentSelectedAppName(to_from) {
        var selected_value = $("#ex_rel_" + to_from + "_issue_" + to_from + "_app_id").val();
        return ExRels.settings.external_app_names.filter(function(elem){
            return elem.id == selected_value
        })[0].app_name;
    }

    function resetInput(to_from) {
        $("#ex_rel_" + to_from + "_issue_" + to_from + "_id").val('');
    }

    function addAddButton(to_from) {
        let link = $('<a class="icon icon-add" href="#" id="ex_rel_' + to_from + '_add_before_submit">追加</a>');
        $('#ex_rel_' + to_from + '-form input[type=submit]').after(link);
        $('#ex_rel_' + to_from + '-form input[type=submit]').hide();
    }

    function exchangeAutocompleteTargetUrl(to_from) {
        var app_name = getCurrentSelectedAppName(to_from);
        if (app_name == 'local'){
            app_name = local_app_name;
        }
        observeAutocompleteField('ex_rel_' + to_from + '_issue_' + to_from + '_id', '/' + app_name + '/issues/auto_complete?scope=all');
    }

    function initialize(to_from){
        addAddButton(to_from);

        // --- input area settings ---
        $('#ex_rel_' + to_from + '_add_before_submit').on('click', function() {
            addExRels(to_from);
        });

        // cancel to submit with enter-key
        $('#ex_rel_' + to_from + '-form input[type="text"]').on('keypress', function(event) {
            if(event.keyCode == 13) {
                addExRels(to_from);
                return false;
            }
        });

        // auto complete settings
        $('#ex_rel_' + to_from + '_issue_' + to_from + '_id').attr('class', 'ui-autocomplete-input autocomplete');
        $('#ex_rel_' + to_from + '_issue_' + to_from + '_app_id').change(function(){
            exchangeAutocompleteTargetUrl(to_from);
            resetInput(to_from);
        });

        exchangeAutocompleteTargetUrl(to_from);  // initialize
    }

    initialize('from');


    // break link
    function get_appname_by_id(id){
        let exrels_app = ExRels.settings.external_app_names.filter(function (item) {return item.id == id})[0];
        return exrels_app.app_name;
    }

    function breakLink(element, to_from) {
        if (!confirm(ExRels.settings.message.confirm_break_link)) {
            return false;
        }
        var tr = $(element).closest('tr')[0];
        var exrels_id = parseInt(tr.dataset['exrels_id']);
        var issue_app_id = parseInt(tr.dataset['issue_' + rev_to_from(to_from) + '_app_id']);
        var issue_id = parseInt(tr.dataset['issue_' + rev_to_from(to_from) + '_id']);
        var app_name = (issue_app_id == 1) ? local_app_name : get_appname_by_id(issue_app_id);
        $.support.cors = true;
        $.ajax({
            type    : 'delete',
            url     : '/' + app_name + '/external_relations/items/' + exrels_id + '.json',
            headers: {
                'X-Redmine-API-Key': apikey
            }
        }).done(function() {
            let data_redraw = {
                'issue_id': issue_id,
                'data_type': to_from
            }
            redrawTable(data_redraw);
        }).fail(function() {
            alert(ExRels.settings.message.error_break_link);
        });
    }

    $('#external_relations_issue_from_table_outer td.buttons a').on('click', function(){
        breakLink(this, 'from');
    });
});