Cardamom = require './cardamom'
db = new Cardamom "#{__dirname}/test"
db.emitter.on 'log', console.log
db.write 'posts', 'this_is_a_test', 'some test content'
db.write 'comments', 'this_is_a_comment', 'some test other test content'
db.write 'comments', 'this_is_another_comment', 'one more comment'
db.link 'posts', 'this_is_a_test', 'comments', 'this_is_a_comment', 'comment'
db.link 'posts', 'this_is_a_test', 'comments', 'this_is_another_comment', 'comment'
db.readLinks 'posts', 'this_is_a_test', 'comment', console.log

