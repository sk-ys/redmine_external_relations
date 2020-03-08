$(function () {
    let get_app_name_by_id = function (id){
        let exrels_app = ExRels.settings.external_app_names.filter(function (item) {return item.id == id})[0];
        return exrels_app.app_name;
    }

    let get_app_title_by_id = function (id){
        let exrels_app = ExRels.settings.external_app_names.filter(function (item) {return item.id == id})[0];
        return exrels_app.app_title;
    }

    let get_data = function (to_from) {
        // get external issues information from from-data
        let trs = $("#external_relations_issue_" + to_from + "_table_outer>table.list>tbody>tr");
        trs.each(function (index, tr) {
            var issue_id = parseInt(tr.dataset['issue_' + to_from + '_id']);
            var issue_app_id = parseInt(tr.dataset['issue_' + to_from + '_app_id']);
            if (issue_app_id == 1){
                return true;  // continue
            }
            var app_name = get_app_name_by_id(issue_app_id);
            var target_url = '/' + app_name + '/issues/' + String(issue_id) + '.json';

            $.getJSON(target_url).done(function (data, textStatus, jqXHR) {
                put_data(issue_app_id, data, tr);
            });
        });
    }

    let get_data_from = function() {get_data('from')}

    let get_data_to = function() {get_data('to')}

    let progress_bar_html = function (progress) {
        let html = '<table class="progress progress-' + progress + '">'
        html += '<tbody><tr>'
        if (progress == 100) {
            html += '<td style="width: 100%;" class="closed" title="100%"></td>'
        } else if (progress > 0) {
            html += '<td style="width: ' + progress + '%;" class="closed" title="' + progress + '%"></td>'
        }
        if (progress < 100) {
            html += '<td style="width: ' + (100 - progress) + '%;" class="todo"></td>'
        }
        html += '</tr></tbody></table>'
        return html
    }

    let a_tag = function (text, path) {
        return '<a href="' + path + '">' + text + '</a>'
    }

    let put_data = function (app_id, data, tr) {
        var app_name = get_app_name_by_id(app_id);
        var app_title = get_app_title_by_id(app_id);
        let tds = $(tr).children("td");
        tds.each(function (index, td) {
            switch (td.className) {
                case "#":
                    // do nothing
                    break;
                case "subject":
                    $(td).html(app_title + ' ' + a_tag('#' + data.issue.id, '/' + app_name + '/issues/' + data.issue.id) + ": " + data.issue.subject);
                    break;
                case "status":
                    $(td).html(data.issue.status.name);
                    break;
                case "done_ratio":
                    // $(td).html(data.issue.done_ratio);
                    $(td).html(progress_bar_html(data.issue.done_ratio));
                    break;
                case "start_date":
                    $(td).html(format_date(data.issue.start_date));
                    break;
                case "due_date":
                    $(td).html(format_date(data.issue.due_date));
                    break;
            }
        });
    }

    let format_date = function (date_str) {
        if (typeof(date_str) == "string") {
            return date_str.replace(/-/g, '/');
        } else {
            return ""
        }
    }

    ExRels['get_data_from'] = get_data_from;
    ExRels['get_data_to'] = get_data_to;
});