function sync_client_field(field){
	cf = $('#settings_client_field').val();
	$.ajax({
		url: '/sync_client_field',
		data: {custom_field: cf},
		success: function(result_json){
			$('#content .flash').remove();
			result = JSON.parse(result_json);
			if (result['type'] == 'success'){
				$('#content').prepend("<div class='flash notice' id='flash_notice'>"+result['message']+"</div>");
				$('option:not(:first)', field).remove();
				options = []
				$.each(result['data'], function(key, value){
					options.push($("<option></option>").attr('value', value).text(value));
				})
				$(field).append(options)
			} else {
				$('#content').prepend("<div class='flash error' id='flash_error'>"+result['message']+"</div>");
			}
		}
	});
}