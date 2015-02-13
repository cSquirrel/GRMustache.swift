// The MIT License
//
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation

extension NSFormatter: ObjCMustacheBoxable {
    
    // The filter facet of NSFormatter: this function evaluates `formatter(x)`
    // expressions.
    private func filter(box: MustacheBox, error: NSErrorPointer) -> MustacheBox? {
        // NSFormatter documentation for stringForObjectValue: states:
        //
        // > First test the passed-in object to see if it’s of the correct
        // > class. If it isn’t, return nil; but if it is of the right class,
        // > return a properly formatted and, if necessary, localized string.
        if let object = box.value as? NSObject {
            return Box(self.stringForObjectValue(object))
        } else {
            // Not the correct class: return nil, i.e. empty Box.
            return Box()
        }
    }
    
    // A RenderFunction: this function lets formatter provide a custom rendering
    // of sections: {{# formatter }}...{{/ formatter }}.
    private func render(info: RenderingInfo, error: NSErrorPointer) -> Rendering? {
        switch info.tag.type {
        case .Variable:
            // {{ formatter }}
            // Behave as a regular object: render self's description
            return Rendering("\(self)")
        case .Section:
            // {{# formatter }}...{{/ formatter }}
            // Render normally, but listen to all inner tags rendering, so that
            // we can format them. See the willRender() method, below.
            let context = info.context.extendedContext(Box(self))
            return info.tag.render(context, error: error)
        }
    }
    
    // A WillRenderFunction: this function lets formatter change values that
    // are about to be rendered to their formatted counterpart.
    //
    // It is activated in the render() method, above.
    private func willRender(tag: Tag, box: MustacheBox) -> MustacheBox {
        switch tag.type {
        case .Variable:
            // {{ value }}
            // Format the value if we can.
            
            if let object = box.value as? NSObject {
                // NSFormatter documentation for stringForObjectValue: states:
                //
                // > First test the passed-in object to see if it’s of the correct
                // > class. If it isn’t, return nil; but if it is of the right class,
                // > return a properly formatted and, if necessary, localized string.
                //
                // So nil result means that object is not of the correct class. Leave
                // it untouched.
                
                if let formatted = self.stringForObjectValue(object) {
                    return Box(formatted)
                }
            }
            return box
            
        case .Section:
            // {{# value }}...{{/ value }}
            // {{^ value }}...{{/ value }}
            // Leave sections untouched, so that loops and conditions are not
            // affected by the formatter.
            
            return box
        }
    }
    
    
    // MARK: - ObjCMustacheBoxable
    
    /**
    Let NSFormatter feed Mustache templates.
    
    NSFormatter can be used as a filter:
    
    ::
    
      let percentFormatter = NSNumberFormatter()
      percentFormatter.numberStyle = .PercentStyle
    
      var template = Template(string: "{{ percent(x) }}")!
      template.registerInBaseContext("percent", Box(percentFormatter))
    
      // Renders "50%"
      template.render(Box(["x": 0.5]))!
    
    
    NSFormatter can also format all variable tags in a Mustache section:
    
    ::
    
      template = Template(string:
          "{{# percent }}" +
            "{{#ingredients}}" +
              "- {{name}} ({{proportion}})\n" +
            "{{/ingredients}}" +
          "{{/percent}}")!
      template.registerInBaseContext("percent", Box(percentFormatter))
      
      // - bread (50%)
      // - ham (35%)
      // - butter (15%)
      var data = [
          "ingredients":[
              ["name": "bread", "proportion": 0.5],
              ["name": "ham", "proportion": 0.35],
              ["name": "butter", "proportion": 0.15]]]
      template.render(Box(data))!
      
    As seen in the example above, variable tags buried inside inner sections are
    escaped as well, so that you can render loop and conditional sections.
    However, values that can't be formatted are left untouched.
    
    Precisely speaking, "values that can't be formatted" are the ones for which
    -[NSFormatter stringForObjectValue:] method return nil, as stated by
    NSFormatter documentation https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSFormatter_Class/index.html#//apple_ref/occ/instm/NSFormatter/stringForObjectValue:
    
    Typically, NSNumberFormatter only formats numbers, and NSDateFormatter,
    dates: you can safely mix various data types in a section controlled by
    those well-behaved formatters.
    */
    public override var mustacheBox: ObjCMustacheBox {
        // Return a multi-facetted box, because NSFormatter interacts in
        // various ways with Mustache rendering. See the documentation of
        // render, filter and willRender methods for more information.
        return ObjCMustacheBox(Box(
            value: self,
            render: render,
            filter: Filter(filter),
            willRender: willRender))
    }
}
