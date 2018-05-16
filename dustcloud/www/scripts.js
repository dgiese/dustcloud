function update_last_contact()
{
  $.ajax({
    url: "/api.php",
    data: {
      cmd: 'last_contact',
      did: $("#settings").attr('did')
    },
    success: function( result ) {
      $( "#last_contact" ).html( result );
    },
    error: function( result ) {
      $( "#last_contact" ).html( "<span class='red'><strong>API connection error</strong></span>" );
    }
  });
}


window.setInterval(function(){
   update_last_contact();
}, 5000);

$(document).ready(function(){
  update_last_contact();
});
