package main
fun main() int {
    var a atomic int16 = new {}
    var b atomic byte  = new {}
    var c atomic bool  = new {}
    a.Add(5)
    b.Add(7)
    c.Write(true)
    var x int16 = a.Read()
    var y byte  = b.Read()
    var z bool  = c.Read()
    if z {
        if x == 5 {
            if y == 7 { ret 42 }
        }
    }
    ret 0
}
