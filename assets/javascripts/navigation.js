function openUrl(obj) {
  var widget = $(obj).find('.widget');
  var url = widget.data('url');
  if(url)
  window.location.href = url;
}

$(function() {
 $('li').live('click', function(e){
  openUrl(this);
});
$('li').live('touchend', function(e){
  openUrl(this);
});
});