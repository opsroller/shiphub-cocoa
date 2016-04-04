import React from 'react'
import ReactDOM from 'react-dom'
import SmartInput from './smart-input.js'
import h from './h.js'

import $ from 'jquery'
window.$ = $;
window.jQuery = $;
window.jquery = $;
require('script-loader!typeahead.js')

var Completer = React.createClass({
  propTypes: {
    value: React.PropTypes.string,
    placeholder: React.PropTypes.string,
    onChange: React.PropTypes.func,
    matcher: React.PropTypes.func.isRequired, /* function matcher(text, callback) => ( callback([match1, match2, ...]) ) */
  },
  
  render: function() {
    var props = Object.assign({}, this.props, {
      className: 'typeahead',
      ref: 'typeInput'
    });
  
    return h(SmartInput, props);
  },
  
  updateTypeahead: function() {
    var el = ReactDOM.findDOMNode(this.refs.typeInput);
    var baseMatcher = this.props.matcher;
    
    var matcher = (text, cb) => {
      if (this.opening) {
        /* 
          If opening for the first time, show all possible choices, but put the
          current choice (if any) first
        */
        this.opening = false;
        baseMatcher("", function(results) {
          // move text to front of results
          var re = new RegExp("^" + text + "$", 'i');
          var ft = results.filter((r) => {
            return !re.test(r);
          });
          if (ft.length < results.length) {
            ft = [text, ...ft];
          }
          cb(ft);
        });
      } else {
        baseMatcher(text, cb);
      }
    };
    
    $(el).typeahead('destroy');
        
    $(el).typeahead({
      hint: true,
      highlight: true,
      minLength: 0,
      autoselect: true,
    }, {
      limit: 20,
      source: matcher
    })
    
    // avoid choosing the first option if we're empty
    // (allow empty to be chosen)
    $(el).on('typeahead:beforeautocomplete', function() {
      return (el.value !== '');
    });
    
    $(el).on('typeahead:beforeopen', () => {
      this.opening = true;
    });
    
    // work around a bug where WebKit doesn't draw the text caret
    // when tabbing to the field and nothing is in it.
    $(el).focus(function() {
      setTimeout(function() {
        if (el.value.length == 0) {
          el.setSelectionRange(0, el.value.length);
        }
      }, 0);
    });
    
    var completeOrFail = () => {
      var val = el.value;
      matcher(val, (matches) => {
        if (val.length == 0 || matches.length == 0) {
          el.value = "";
        } else {
          var first = matches[0];
          el.value = first;
        }
      });
    }
    
    $(el).blur(completeOrFail);
    
    $(el).keypress(function(evt) {
      if (evt.which == 13) {
        completeOrFail();
        evt.preventDefault();
      }
    });
  },
  
  componentDidUpdate: function() {
    this.updateTypeahead();
  },
  
  componentDidMount: function() {
    this.updateTypeahead();
  }
});

Completer.PrefixMatcher = function(options) {
  return function(text, cb) {
    var r = new RegExp("^" + text, 'i');
    cb(options.filter((o) => (r.test(o))));
  }
}

Completer.SubstrMatcher = function(options) {
  return function(text, cb) {
    var r = new RegExp(text, 'i');
    cb(options.filter((o) => (r.test(o))));
  }
}

export default Completer;