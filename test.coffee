Cardamom = require './cardamom'
db = new Cardamom "#{__dirname}/test"
db.emitter.on 'log', console.log
db.write 'posts', 'this_is_a_test', 'some test content', console.log
