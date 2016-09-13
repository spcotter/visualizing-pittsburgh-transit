var fs = require('fs');
var directory = '~/GitHub/visualizing-pittsburgh-transit';
var positions1m = JSON.parse(fs.readFileSync(directory + '/positions1m.json', 'utf8'));

var minutes = Object.keys(positions1m),
    trips1m = {};

minutes.forEach(function(m){
  console.log(m);
  var trips = positions1m[m];

  trips.forEach(function(trip){

    var new_trip = trips1m[ trip[1] ],
        coords = [ +trip[2], +trip[3] ];

    if(new_trip){
      new_trip.positions.push(coords);
    } else {
      new_trip = { route: trip[0], start_time: m, positions: [coords] }
      trips1m[trip[1]] = new_trip;
    }

  });

});


var new_positions1m = {};

minutes.forEach(function(m){
  new_positions1m[m] = [];
});


Object.keys(trips1m).forEach(function(t){
  var trip = trips1m[t];
  trip.trip = t
  new_positions1m[trip.start_time].push(trip);
});


console.log( new_positions1m['05:29'][0] );


fs.writeFile(directory + '/new_positions1m.json', JSON.stringify(new_positions1m), function(){ console.log('File written'); })






// 

var minutes = Object.keys(positions1m),
    new_positions = { start_time: 180, positions: [] };

minutes.forEach(function(m){
  console.log(m);
  var trips = positions1m[m],
      new_trips = {};

  trips.forEach(function(trip){
    new_trips[ trip[1] + '.' + trip[0].substr(0,1) ] = [ +trip[3], +trip[2] ];
  });

  new_positions.positions.push(new_trips);


});


new_positions.positions.slice(40,45)

fs.writeFile(directory + '/canvas_positions1m.json', JSON.stringify(new_positions), function(){ console.log('File written'); })



