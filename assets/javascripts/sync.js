function sync_client_field(biller_field, client_field){
	client_custom_field = $('#settings_client_field').val();
	biller = $(biller_field).val();
	$.ajax({
		url: '/sync_client_field',
		data: {client_custom_field: client_custom_field, biller: biller},
		success: function(result_json){
			console.log("HOLA");
			$('#content .flash').remove();
			result = JSON.parse(result_json);
			if (result['type'] == 'success'){
				$('#content').prepend("<div class='flash notice' id='flash_notice'>"+result['message']+"</div>");
				if (client_custom_field == undefined){
					update_clients(result['data'], client_field);
				}
			} else {
				$('#content').prepend("<div class='flash error' id='flash_error'>"+result['message']+"</div>");
			}
		}
	});
}

function change_biller(biller_field, client_field){
	biller = $(biller_field).val();
	$.ajax({
		url: '/get_clients',
		data: {biller: biller},
		success: function(result_json){
			result = JSON.parse(result_json);
			update_clients(result, client_field);
		}
	});
}


function update_clients(data, client_field){
	selected = $('option:selected', client_field).text();
	$('option:not(:first)', client_field).remove();
	options = []
	$.each(data, function(key, value){
		if (value == selected){
			options.push($("<option></option>").attr('value', value).text(value).prop("selected",true));
		} else {
			options.push($("<option></option>").attr('value', value).text(value));
		}
	})
	$(client_field).append(options)
}